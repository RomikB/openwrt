/*
 * nvram-env: Drop-in C replacement for stock Xiaomi/Broadcom nvram and bdata tools.
 *
 * Implements nvram/bdata get, set, unset, show, commit, and sync on top of
 * uboot-envtools (fw_printenv / fw_setenv) with fast in-memory tmpfs caching.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <dirent.h>
#include <errno.h>
#include <limits.h>

#define DIR_PATH_SIZE  128
#define SUB_DIR_SIZE   192
#define FILE_PATH_SIZE 512
#define CMD_BUF_SIZE   1024

typedef struct {
    const char *prog_name;
    const char *env_name;
    char state_dir[DIR_PATH_SIZE];
    char vars_dir[SUB_DIR_SIZE];
    char del_dir[SUB_DIR_SIZE];
    char init_file[SUB_DIR_SIZE];
    char dirty_file[SUB_DIR_SIZE];
    char lock_file[SUB_DIR_SIZE];
    char print_cmd[DIR_PATH_SIZE];
    char set_cmd[DIR_PATH_SIZE];
    int lock_fd;
} env_ctx_t;

static env_ctx_t g_ctx;

static int mkdir_p(const char *path) {
    char tmp[FILE_PATH_SIZE];
    char *p = NULL;
    size_t len;

    snprintf(tmp, sizeof(tmp), "%s", path);
    len = strlen(tmp);
    if (len == 0) return 0;
    if (tmp[len - 1] == '/') tmp[len - 1] = 0;

    for (p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
                return -1;
            }
            *p = '/';
        }
    }
    if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
        return -1;
    }
    return 0;
}

static void acquire_lock(env_ctx_t *ctx) {
    if (ctx->lock_fd >= 0) return;
    mkdir_p(ctx->state_dir);
    mkdir_p(ctx->vars_dir);
    mkdir_p(ctx->del_dir);
    ctx->lock_fd = open(ctx->lock_file, O_CREAT | O_RDWR, 0600);
    if (ctx->lock_fd >= 0) {
        flock(ctx->lock_fd, LOCK_EX);
    }
}

static void release_lock(env_ctx_t *ctx) {
    if (ctx->lock_fd >= 0) {
        flock(ctx->lock_fd, LOCK_UN);
        close(ctx->lock_fd);
        ctx->lock_fd = -1;
    }
}

static void init_context(env_ctx_t *ctx, const char *argv0) {
    const char *base = strrchr(argv0, '/');
    base = base ? base + 1 : argv0;

    memset(ctx, 0, sizeof(*ctx));
    ctx->prog_name = base;
    ctx->lock_fd = -1;

    if (strstr(base, "bdata") != NULL) {
        ctx->env_name = "bdata";
        if (access("/usr/sbin/fw_printsys", X_OK) == 0) {
            snprintf(ctx->print_cmd, sizeof(ctx->print_cmd), "/usr/sbin/fw_printsys");
            snprintf(ctx->set_cmd, sizeof(ctx->set_cmd), "/usr/sbin/fw_setsys -s");
        } else if (access("/usr/sbin/fw_printenv", X_OK) == 0) {
            snprintf(ctx->print_cmd, sizeof(ctx->print_cmd), "/usr/sbin/fw_printenv -c /etc/fw_sys.config");
            snprintf(ctx->set_cmd, sizeof(ctx->set_cmd), "/usr/sbin/fw_setenv -c /etc/fw_sys.config -s");
        } else {
            snprintf(ctx->print_cmd, sizeof(ctx->print_cmd), "fw_printenv -c /etc/fw_sys.config");
            snprintf(ctx->set_cmd, sizeof(ctx->set_cmd), "fw_setenv -c /etc/fw_sys.config -s");
        }
    } else {
        ctx->env_name = "nvram";
        if (access("/usr/sbin/fw_printenv", X_OK) == 0) {
            snprintf(ctx->print_cmd, sizeof(ctx->print_cmd), "/usr/sbin/fw_printenv");
            snprintf(ctx->set_cmd, sizeof(ctx->set_cmd), "/usr/sbin/fw_setenv -s");
        } else {
            snprintf(ctx->print_cmd, sizeof(ctx->print_cmd), "fw_printenv");
            snprintf(ctx->set_cmd, sizeof(ctx->set_cmd), "fw_setenv -s");
        }
    }

    snprintf(ctx->state_dir, sizeof(ctx->state_dir), "/tmp/state/%s", ctx->env_name);
    snprintf(ctx->vars_dir, sizeof(ctx->vars_dir), "%s/vars", ctx->state_dir);
    snprintf(ctx->del_dir, sizeof(ctx->del_dir), "%s/deleted", ctx->state_dir);
    snprintf(ctx->init_file, sizeof(ctx->init_file), "%s/.initialized", ctx->state_dir);
    snprintf(ctx->dirty_file, sizeof(ctx->dirty_file), "%s/dirty", ctx->state_dir);
    snprintf(ctx->lock_file, sizeof(ctx->lock_file), "%s.lock", ctx->state_dir);
}

static void init_cache_if_needed(env_ctx_t *ctx) {
    if (access(ctx->init_file, F_OK) == 0) {
        return;
    }

    acquire_lock(ctx);
    if (access(ctx->init_file, F_OK) == 0) {
        release_lock(ctx);
        return;
    }

    mkdir_p(ctx->vars_dir);
    mkdir_p(ctx->del_dir);

    FILE *fp = popen(ctx->print_cmd, "r");
    if (fp) {
        char *line = NULL;
        size_t cap = 0;
        ssize_t nread;

        while ((nread = getline(&line, &cap, fp)) != -1) {
            while (nread > 0 && (line[nread - 1] == '\n' || line[nread - 1] == '\r')) {
                line[--nread] = '\0';
            }
            if (nread == 0) continue;

            char *eq = strchr(line, '=');
            if (eq) {
                *eq = '\0';
                char *k = line;
                char *v = eq + 1;

                if (strchr(k, '/') == NULL && strlen(k) > 0) {
                    char var_path[FILE_PATH_SIZE];
                    snprintf(var_path, sizeof(var_path), "%s/%s", ctx->vars_dir, k);
                    FILE *vf = fopen(var_path, "wb");
                    if (vf) {
                        fputs(v, vf);
                        fclose(vf);
                        chmod(var_path, 0644);
                    }
                }
            }
        }
        free(line);
        pclose(fp);
    }

    int ifd = open(ctx->init_file, O_CREAT | O_WRONLY, 0644);
    if (ifd >= 0) close(ifd);

    release_lock(ctx);
}

static int do_get(env_ctx_t *ctx, const char *key) {
    if (!key || strchr(key, '/') != NULL || strlen(key) == 0) {
        return 0;
    }

    init_cache_if_needed(ctx);

    char del_path[FILE_PATH_SIZE];
    snprintf(del_path, sizeof(del_path), "%s/%s", ctx->del_dir, key);
    if (access(del_path, F_OK) == 0) {
        return 0;
    }

    char var_path[FILE_PATH_SIZE];
    snprintf(var_path, sizeof(var_path), "%s/%s", ctx->vars_dir, key);
    FILE *f = fopen(var_path, "rb");
    if (!f) {
        return 0;
    }

    char buf[1024];
    size_t nr;
    while ((nr = fread(buf, 1, sizeof(buf), f)) > 0) {
        if (fwrite(buf, 1, nr, stdout) != nr) {
            break;
        }
    }
    putchar('\n');
    fclose(f);
    return 0;
}

static int do_set(env_ctx_t *ctx, const char *key, const char *val) {
    if (!key || strchr(key, '/') != NULL || strlen(key) == 0) {
        return 1;
    }

    init_cache_if_needed(ctx);
    acquire_lock(ctx);

    char del_path[FILE_PATH_SIZE];
    snprintf(del_path, sizeof(del_path), "%s/%s", ctx->del_dir, key);
    unlink(del_path);

    char tmp_path[FILE_PATH_SIZE];
    snprintf(tmp_path, sizeof(tmp_path), "%s/tmp_set_XXXXXX", ctx->state_dir);
    int tfd = mkstemp(tmp_path);
    if (tfd >= 0) {
        fchmod(tfd, 0644);
        if (val && strlen(val) > 0) {
            if (write(tfd, val, strlen(val)) < 0) {
                /* ignore write error */
            }
        }
        close(tfd);

        char var_path[FILE_PATH_SIZE];
        snprintf(var_path, sizeof(var_path), "%s/%s", ctx->vars_dir, key);
        rename(tmp_path, var_path);
    }

    FILE *df = fopen(ctx->dirty_file, "a");
    if (df) {
        fprintf(df, "%s\n", key);
        fclose(df);
    }

    release_lock(ctx);
    return 0;
}

static int do_unset(env_ctx_t *ctx, const char *key) {
    if (!key || strchr(key, '/') != NULL || strlen(key) == 0) {
        return 1;
    }

    init_cache_if_needed(ctx);
    acquire_lock(ctx);

    char var_path[FILE_PATH_SIZE];
    snprintf(var_path, sizeof(var_path), "%s/%s", ctx->vars_dir, key);
    unlink(var_path);

    char del_path[FILE_PATH_SIZE];
    snprintf(del_path, sizeof(del_path), "%s/%s", ctx->del_dir, key);
    int dfd = open(del_path, O_CREAT | O_WRONLY, 0644);
    if (dfd >= 0) close(dfd);

    FILE *df = fopen(ctx->dirty_file, "a");
    if (df) {
        fprintf(df, "%s\n", key);
        fclose(df);
    }

    release_lock(ctx);
    return 0;
}

static int cmp_strings(const void *a, const void *b) {
    const char *sa = *(const char **)a;
    const char *sb = *(const char **)b;
    return strcmp(sa, sb);
}

static int do_show(env_ctx_t *ctx) {
    init_cache_if_needed(ctx);

    DIR *d = opendir(ctx->vars_dir);
    if (!d) return 0;

    char **names = NULL;
    size_t count = 0;
    size_t cap = 0;

    struct dirent *de;
    while ((de = readdir(d)) != NULL) {
        if (de->d_name[0] == '.') continue;

        char del_path[FILE_PATH_SIZE];
        snprintf(del_path, sizeof(del_path), "%s/%s", ctx->del_dir, de->d_name);
        if (access(del_path, F_OK) == 0) {
            continue;
        }

        if (count >= cap) {
            cap = cap ? cap * 2 : 64;
            names = realloc(names, cap * sizeof(char *));
        }
        names[count++] = strdup(de->d_name);
    }
    closedir(d);

    if (names && count > 0) {
        qsort(names, count, sizeof(char *), cmp_strings);

        for (size_t idx = 0; idx < count; idx++) {
            char var_path[FILE_PATH_SIZE];
            snprintf(var_path, sizeof(var_path), "%s/%s", ctx->vars_dir, names[idx]);
            FILE *f = fopen(var_path, "rb");
            if (f) {
                printf("%s=", names[idx]);
                char buf[1024];
                size_t nr;
                while ((nr = fread(buf, 1, sizeof(buf), f)) > 0) {
                    if (fwrite(buf, 1, nr, stdout) != nr) break;
                }
                putchar('\n');
                fclose(f);
            }
            free(names[idx]);
        }
        free(names);
    }

    return 0;
}

typedef struct key_node {
    char *key;
    struct key_node *next;
} key_node_t;

static int do_commit(env_ctx_t *ctx) {
    acquire_lock(ctx);

    if (access(ctx->dirty_file, F_OK) != 0) {
        release_lock(ctx);
        return 0;
    }

    FILE *df = fopen(ctx->dirty_file, "r");
    if (!df) {
        release_lock(ctx);
        return 0;
    }

    key_node_t *head = NULL;
    char line[256];
    while (fgets(line, sizeof(line), df)) {
        char *nl = strchr(line, '\n');
        if (nl) *nl = 0;
        char *cr = strchr(line, '\r');
        if (cr) *cr = 0;
        if (strlen(line) == 0) continue;

        key_node_t *cur = head;
        int found = 0;
        while (cur) {
            if (strcmp(cur->key, line) == 0) {
                found = 1;
                break;
            }
            cur = cur->next;
        }
        if (!found) {
            key_node_t *node = malloc(sizeof(key_node_t));
            node->key = strdup(line);
            node->next = head;
            head = node;
        }
    }
    fclose(df);

    if (!head) {
        unlink(ctx->dirty_file);
        release_lock(ctx);
        return 0;
    }

    char batch_path[FILE_PATH_SIZE];
    snprintf(batch_path, sizeof(batch_path), "%s/batch_commit.tmp", ctx->state_dir);
    FILE *bf = fopen(batch_path, "w");
    if (!bf) {
        while (head) {
            key_node_t *next = head->next;
            free(head->key);
            free(head);
            head = next;
        }
        release_lock(ctx);
        return -1;
    }

    key_node_t *cur = head;
    while (cur) {
        char del_path[FILE_PATH_SIZE];
        snprintf(del_path, sizeof(del_path), "%s/%s", ctx->del_dir, cur->key);
        if (access(del_path, F_OK) == 0) {
            fprintf(bf, "%s\n", cur->key);
        } else {
            char var_path[FILE_PATH_SIZE];
            snprintf(var_path, sizeof(var_path), "%s/%s", ctx->vars_dir, cur->key);
            FILE *vf = fopen(var_path, "rb");
            if (vf) {
                fprintf(bf, "%s ", cur->key);
                char buf[1024];
                size_t nr;
                while ((nr = fread(buf, 1, sizeof(buf), vf)) > 0) {
                    if (fwrite(buf, 1, nr, bf) != nr) break;
                }
                fputc('\n', bf);
                fclose(vf);
            }
        }
        cur = cur->next;
    }
    fclose(bf);

    while (head) {
        key_node_t *next = head->next;
        free(head->key);
        free(head);
        head = next;
    }

    char cmd[CMD_BUF_SIZE];
    snprintf(cmd, sizeof(cmd), "%s %s", ctx->set_cmd, batch_path);
    int res = system(cmd);

    unlink(batch_path);

    if (res == 0) {
        unlink(ctx->dirty_file);
        DIR *d = opendir(ctx->del_dir);
        if (d) {
            struct dirent *de;
            while ((de = readdir(d)) != NULL) {
                if (de->d_name[0] != '.') {
                    char dp[FILE_PATH_SIZE];
                    snprintf(dp, sizeof(dp), "%s/%s", ctx->del_dir, de->d_name);
                    unlink(dp);
                }
            }
            closedir(d);
        }
    } else {
        fprintf(stderr, "%s: commit failed with exit code %d\n", ctx->prog_name, res);
    }

    release_lock(ctx);
    return (res == 0) ? 0 : 1;
}

static void print_usage(const env_ctx_t *ctx) {
    if (strcmp(ctx->env_name, "bdata") == 0) {
        fprintf(stderr, "usage: bdata [get name] [set name=value] [unset name] [show] [commit] [sync] ...\n");
    } else {
        fprintf(stderr, "usage: nvram [get name] [set name=value] [unset name] [show] [commit] ...\n");
    }
}

int main(int argc, char *argv[]) {
    init_context(&g_ctx, argv[0]);

    if (argc < 2) {
        print_usage(&g_ctx);
        return 1;
    }

    int i = 1;
    int ret = 0;

    while (i < argc) {
        const char *cmd = argv[i];

        if (strcmp(cmd, "get") == 0) {
            if (i + 1 >= argc) {
                print_usage(&g_ctx);
                return 1;
            }
            ret = do_get(&g_ctx, argv[i + 1]);
            i += 2;
        } else if (strcmp(cmd, "set") == 0) {
            if (i + 1 >= argc) {
                print_usage(&g_ctx);
                return 1;
            }
            char *arg = argv[i + 1];
            char *eq = strchr(arg, '=');
            if (eq) {
                *eq = '\0';
                ret = do_set(&g_ctx, arg, eq + 1);
                i += 2;
            } else {
                if (i + 2 < argc &&
                    strcmp(argv[i + 2], "get") != 0 &&
                    strcmp(argv[i + 2], "set") != 0 &&
                    strcmp(argv[i + 2], "unset") != 0 &&
                    strcmp(argv[i + 2], "show") != 0 &&
                    strcmp(argv[i + 2], "commit") != 0 &&
                    strcmp(argv[i + 2], "sync") != 0) {
                    ret = do_set(&g_ctx, arg, argv[i + 2]);
                    i += 3;
                } else {
                    ret = do_set(&g_ctx, arg, "");
                    i += 2;
                }
            }
        } else if (strcmp(cmd, "unset") == 0) {
            if (i + 1 >= argc) {
                print_usage(&g_ctx);
                return 1;
            }
            ret = do_unset(&g_ctx, argv[i + 1]);
            i += 2;
        } else if (strcmp(cmd, "show") == 0) {
            ret = do_show(&g_ctx);
            i += 1;
        } else if (strcmp(cmd, "commit") == 0 || strcmp(cmd, "sync") == 0) {
            ret = do_commit(&g_ctx);
            i += 1;
        } else {
            print_usage(&g_ctx);
            return 1;
        }
    }

    return ret;
}
