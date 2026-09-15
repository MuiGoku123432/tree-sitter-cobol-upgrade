#define _POSIX_C_SOURCE 200809L

#include <tree_sitter/api.h>

#include <errno.h>
#include <regex.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern const TSLanguage *tree_sitter_COBOL(void);

typedef struct {
    const char *type;
    TSPoint start;
    TSPoint end;
} InventoryNode;

typedef struct {
    InventoryNode *items;
    size_t count;
    size_t capacity;
} InventoryNodes;

typedef struct {
    uint32_t *items;
    size_t count;
    size_t capacity;
} ErrorRows;

typedef struct {
    TSNode *items;
    size_t count;
    size_t capacity;
} NodeStack;

static int grow(void **items, size_t *capacity, size_t item_size) {
    size_t next = *capacity == 0 ? 64 : *capacity * 2;
    void *resized = realloc(*items, next * item_size);
    if (resized == NULL) {
        return 0;
    }
    *items = resized;
    *capacity = next;
    return 1;
}

static int push_inventory(InventoryNodes *nodes, const char *type,
                          TSPoint start, TSPoint end) {
    if (nodes->count == nodes->capacity &&
        !grow((void **)&nodes->items, &nodes->capacity, sizeof(*nodes->items))) {
        return 0;
    }
    nodes->items[nodes->count++] = (InventoryNode){type, start, end};
    return 1;
}

static int push_error_row(ErrorRows *rows, uint32_t row) {
    if (rows->count == rows->capacity &&
        !grow((void **)&rows->items, &rows->capacity, sizeof(*rows->items))) {
        return 0;
    }
    rows->items[rows->count++] = row;
    return 1;
}

static int push_node(NodeStack *stack, TSNode node) {
    if (stack->count == stack->capacity &&
        !grow((void **)&stack->items, &stack->capacity, sizeof(*stack->items))) {
        return 0;
    }
    stack->items[stack->count++] = node;
    return 1;
}

static int has_error_on_row(const ErrorRows *rows, uint32_t row) {
    for (size_t i = 0; i < rows->count; i++) {
        if (rows->items[i] == row) {
            return 1;
        }
    }
    return 0;
}

static char *read_source(const char *path, uint32_t *length) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return NULL;
    }
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }
    long size = ftell(file);
    if (size < 0 || (uint64_t)size > UINT32_MAX || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }
    char *source = malloc((size_t)size + 1);
    if (source == NULL) {
        fclose(file);
        return NULL;
    }
    size_t read_count = fread(source, 1, (size_t)size, file);
    if (read_count != (size_t)size || ferror(file)) {
        free(source);
        fclose(file);
        return NULL;
    }
    fclose(file);
    source[size] = '\0';
    *length = (uint32_t)size;
    return source;
}

static int collect_nodes(TSNode root, const regex_t *node_regex,
                         InventoryNodes *nodes, ErrorRows *error_rows) {
    NodeStack stack = {0};
    if (!push_node(&stack, root)) {
        return 0;
    }
    while (stack.count > 0) {
        TSNode node = stack.items[--stack.count];
        const char *type = ts_node_type(node);
        TSPoint start = ts_node_start_point(node);
        TSPoint end = ts_node_end_point(node);
        if (ts_node_is_error(node)) {
            if (!push_error_row(error_rows, start.row)) {
                free(stack.items);
                return 0;
            }
        } else if (regexec(node_regex, type, 0, NULL, 0) == 0) {
            if (!push_inventory(nodes, type, start, end)) {
                free(stack.items);
                return 0;
            }
        }
        uint32_t child_count = ts_node_child_count(node);
        for (uint32_t i = child_count; i > 0; i--) {
            if (!push_node(&stack, ts_node_child(node, i - 1))) {
                free(stack.items);
                return 0;
            }
        }
    }
    free(stack.items);
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 7) {
        fprintf(stderr, "usage: %s CORPUS_ROOT NUL_PATHS INVENTORY STATS TIMEOUT_US NODE_REGEX\n", argv[0]);
        return 2;
    }

    const char *corpus_root = argv[1];
    const char *paths_path = argv[2];
    const char *inventory_path = argv[3];
    const char *stats_path = argv[4];
    uint64_t timeout_us = strtoull(argv[5], NULL, 10);
    const char *node_pattern = argv[6];

    regex_t node_regex;
    if (regcomp(&node_regex, node_pattern, REG_EXTENDED | REG_NOSUB) != 0) {
        fprintf(stderr, "invalid node regex\n");
        return 2;
    }

    FILE *paths = fopen(paths_path, "rb");
    FILE *inventory = fopen(inventory_path, "wb");
    FILE *stats = fopen(stats_path, "wb");
    if (paths == NULL || inventory == NULL || stats == NULL) {
        fprintf(stderr, "could not open helper input/output: %s\n", strerror(errno));
        if (paths != NULL) fclose(paths);
        if (inventory != NULL) fclose(inventory);
        if (stats != NULL) fclose(stats);
        regfree(&node_regex);
        return 2;
    }

    TSParser *parser = ts_parser_new();
    if (parser == NULL || !ts_parser_set_language(parser, tree_sitter_COBOL())) {
        fprintf(stderr, "could not initialize COBOL parser\n");
        fclose(paths);
        fclose(inventory);
        fclose(stats);
        regfree(&node_regex);
        if (parser != NULL) ts_parser_delete(parser);
        return 2;
    }
    ts_parser_set_timeout_micros(parser, timeout_us);

    size_t root_length = strlen(corpus_root);
    char *path = NULL;
    size_t path_capacity = 0;
    size_t files_walked = 0;
    size_t files_failed = 0;
    size_t files_timed_out = 0;
    size_t files_with_errors = 0;
    size_t files_zero_match = 0;
    size_t records_written = 0;

    while (getdelim(&path, &path_capacity, '\0', paths) != -1) {
        size_t path_length = strlen(path);
        files_walked++;
        if (files_walked % 1000 == 0) {
            fprintf(stderr,
                    "snapshot: progress files_walked=%zu files_failed_to_emit_tree=%zu files_timed_out=%zu files_with_parse_errors=%zu records_found=%zu\n",
                    files_walked, files_failed, files_timed_out,
                    files_with_errors, records_written);
            fflush(stderr);
        }

        if (path_length <= root_length || strncmp(path, corpus_root, root_length) != 0 ||
            path[root_length] != '/') {
            files_failed++;
            continue;
        }
        const char *relative_path = path + root_length + 1;

        uint32_t source_length = 0;
        char *source = read_source(path, &source_length);
        if (source == NULL) {
            files_failed++;
            continue;
        }

        ts_parser_reset(parser);
        TSTree *tree = ts_parser_parse_string(parser, NULL, source, source_length);
        free(source);
        if (tree == NULL) {
            files_timed_out++;
            files_failed++;
            continue;
        }

        TSNode root = ts_tree_root_node(tree);
        if (ts_node_has_error(root)) {
            files_with_errors++;
        }

        InventoryNodes nodes = {0};
        ErrorRows error_rows = {0};
        if (!collect_nodes(root, &node_regex, &nodes, &error_rows)) {
            free(nodes.items);
            free(error_rows.items);
            ts_tree_delete(tree);
            files_failed++;
            continue;
        }

        if (nodes.count == 0) {
            files_zero_match++;
        }
        for (size_t i = 0; i < nodes.count; i++) {
            const InventoryNode *node = &nodes.items[i];
            const char *qualifier = has_error_on_row(&error_rows, node->end.row)
                                        ? "trailing_error"
                                        : "clean";
            if (fprintf(inventory, "%s\t%u,%u\t%s\t%s\n",
                        relative_path, node->start.row, node->start.column,
                        node->type, qualifier) < 0) {
                files_failed++;
                break;
            }
            records_written++;
        }

        free(nodes.items);
        free(error_rows.items);
        ts_tree_delete(tree);
    }

    free(path);
    ts_parser_delete(parser);
    regfree(&node_regex);
    fclose(paths);

    if (fprintf(stats, "%zu %zu %zu %zu %zu %zu\n",
                files_walked, files_failed, files_timed_out,
                files_with_errors, files_zero_match, records_written) < 0 ||
        fclose(inventory) != 0 || fclose(stats) != 0) {
        return 2;
    }

    return files_failed == 0 ? 0 : 1;
}
