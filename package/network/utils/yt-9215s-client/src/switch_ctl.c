// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Open-source switch_ctl CLI utility for Motorcomm YT9215S
 * Compatible with Xiaomi BE3600 (RD15) platform scripts
 *
 * Replaces proprietary vendor binary from yt-9215s-client-vendor.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>

#define PROC_SMI "/proc/smi"

#define SWITCH_CTL_FDB_DUMP        0x200
#define SWITCH_CTL_SW_REG_W        0x201
#define SWITCH_CTL_SW_REG_R        0x202
#define SWITCH_CTL_PHY_FC          0x203
#define SWITCH_CTL_PHY_POWER       0x204
#define SWITCH_CTL_PHY_AN_GET      0x205
#define SWITCH_CTL_PHY_AN_SET      0x206
#define SWITCH_CTL_PHY_SPEED_DUP   0x207
#define SWITCH_CTL_PHY_REG_W       0x208
#define SWITCH_CTL_PHY_REG_R       0x209
#define SWITCH_CTL_PHY_GAME_SET    0x20a
#define SWITCH_CTL_PHY_GAME_DIS    0x20b
#define SWITCH_CTL_FORWARD         0x20c

struct sw_reg_cmd {
	uint32_t addr;
	uint32_t val;
};

struct phy_fc_cmd {
	uint8_t phy_id;
	uint8_t fc;
};

struct phy_power_cmd {
	uint8_t phy_id;
	uint32_t power;
};

struct phy_an_cmd {
	uint8_t phy_id;
	uint32_t enable;
	uint32_t speed_mask;
};

struct phy_speed_cmd {
	uint8_t phy_id;
	uint32_t speed;
	uint32_t duplex;
};

struct phy_reg_cmd {
	uint8_t phy_id;
	uint32_t addr;
	uint16_t val;
};

struct phy_game_cmd {
	uint8_t phy_id;
};

struct fdb_entry {
	uint8_t mac[6];
	uint16_t flags;
	uint32_t vid;
	uint32_t port;
};

static int switch_ctl_ioctl(int cmd, void *arg)
{
	int fd = open(PROC_SMI, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "[switch_ctl] switch_ctl_ioctl[%d]:open /proc/smi ioctl file error\n", __LINE__);
		return -1;
	}

	int ret = ioctl(fd, cmd, arg);
	if (ret < 0) {
		fprintf(stderr, "[switch_ctl] switch_ctl_ioctl[%d]:/proc/smi ioctl error\n", __LINE__);
		close(fd);
		return -1;
	}

	close(fd);
	return 0;
}

static void usage(void)
{
	printf("Format:switch_ctl\n"
	       "                switch_ctl fdb dump\n"
	       "                switch_ctl sw_reg w [reg_addr] [reg_value]\n"
	       "                switch_ctl sw_reg r [reg_addr]\n"
	       "                switch_ctl phy [phy_id] fc 0/1\n"
	       "                switch_ctl phy [phy_id] power 0/1\n"
	       "                switch_ctl phy [phy_id] autoNeg [0/10/100/1000]\n"
	       "                switch_ctl phy [phy_id] speed [speed] duplex [half/full]\n"
	       "                switch_ctl phy [phy_id] w [reg_addr] [reg_value]\n"
	       "                switch_ctl phy [phy_id] r [reg_addr]\n"
	       "                switch_ctl phy [phy_id] game set\n"
	       "                switch_ctl phy game disable\n"
	       "                switch_ctl forward [0:disable/1:enable]\n");
}

int main(int argc, char *argv[])
{
	if (argc < 2) {
		usage();
		return -1;
	}

	if (!strcmp(argv[1], "forward")) {
		if (argc < 3) {
			usage();
			return -1;
		}
		uint8_t fwd = (uint8_t)strtoul(argv[2], NULL, 0);
		if (switch_ctl_ioctl(SWITCH_CTL_FORWARD, &fwd) < 0)
			return -1;
		return 0;
	}

	if (!strcmp(argv[1], "fdb")) {
		if (argc < 3 || strcmp(argv[2], "dump") != 0) {
			usage();
			return -1;
		}
		size_t bufsz = 65536;
		uint8_t *buf = calloc(1, bufsz);
		if (!buf)
			return -ENOMEM;
		printf("       MAC           VID   PORT\n");
		if (switch_ctl_ioctl(SWITCH_CTL_FDB_DUMP, buf) == 0) {
			struct fdb_entry *e = (struct fdb_entry *)buf;
			for (size_t i = 0; i < bufsz / sizeof(struct fdb_entry); i++) {
				if (e[i].mac[0] == 0 && e[i].mac[1] == 0 && e[i].mac[2] == 0 &&
				    e[i].mac[3] == 0 && e[i].mac[4] == 0 && e[i].mac[5] == 0)
					continue;
				printf("%02x:%02x:%02x:%02x:%02x:%02x     %d     %d\n",
				       e[i].mac[0], e[i].mac[1], e[i].mac[2],
				       e[i].mac[3], e[i].mac[4], e[i].mac[5],
				       e[i].vid, e[i].port);
			}
		}
		free(buf);
		return 0;
	}

	if (!strcmp(argv[1], "sw_reg")) {
		if (argc < 4) {
			usage();
			return -1;
		}
		if (!strcmp(argv[2], "w")) {
			if (argc < 5) {
				usage();
				return -1;
			}
			struct sw_reg_cmd reg;
			reg.addr = (uint32_t)strtoul(argv[3], NULL, 16);
			reg.val = (uint32_t)strtoul(argv[4], NULL, 16);
			if (switch_ctl_ioctl(SWITCH_CTL_SW_REG_W, &reg) < 0) {
				fprintf(stderr, "[switch_ctl] main[%d]:switch_ctl sw_reg w error\n", __LINE__);
				return -1;
			}
			return 0;
		} else if (!strcmp(argv[2], "r")) {
			struct sw_reg_cmd reg = {0};
			reg.addr = (uint32_t)strtoul(argv[3], NULL, 16);
			if (switch_ctl_ioctl(SWITCH_CTL_SW_REG_R, &reg) < 0) {
				fprintf(stderr, "[switch_ctl] main[%d]:switch_ctl sw_reg r error\n", __LINE__);
				return -1;
			}
			printf("[switch_ctl] main[%d]:switch_ctl sw_reg r 0x%x value 0x%x\n", __LINE__, reg.addr, reg.val);
			return 0;
		} else {
			usage();
			return -1;
		}
	}

	if (!strcmp(argv[1], "phy")) {
		if (argc < 3) {
			usage();
			return -1;
		}

		if (!strcmp(argv[2], "game") && argc >= 4 && !strcmp(argv[3], "disable")) {
			struct phy_game_cmd g = {0};
			return switch_ctl_ioctl(SWITCH_CTL_PHY_GAME_DIS, &g);
		}

		uint8_t phy_id = (uint8_t)strtoul(argv[2], NULL, 0);

		if (argc < 4) {
			usage();
			return -1;
		}

		if (!strcmp(argv[3], "fc")) {
			if (argc < 5) {
				usage();
				return -1;
			}
			struct phy_fc_cmd fc;
			fc.phy_id = phy_id;
			fc.fc = (uint8_t)strtoul(argv[4], NULL, 0);
			if (switch_ctl_ioctl(SWITCH_CTL_PHY_FC, &fc) < 0) {
				fprintf(stderr, "[switch_ctl] main[%d]:switch_ctl phy fc error\n", __LINE__);
				return -1;
			}
			return 0;
		}

		if (!strcmp(argv[3], "power")) {
			if (argc < 5) {
				usage();
				return -1;
			}
			struct phy_power_cmd p;
			p.phy_id = phy_id;
			p.power = (uint32_t)strtoul(argv[4], NULL, 0);
			if (switch_ctl_ioctl(SWITCH_CTL_PHY_POWER, &p) < 0) {
				fprintf(stderr, "[switch_ctl] main[%d]:switch_ctl phy power error\n", __LINE__);
				return -1;
			}
			return 0;
		}

		if (!strcmp(argv[3], "autoNeg")) {
			if (argc >= 5 && !strcmp(argv[4], "get")) {
				struct phy_an_cmd an = {0};
				an.phy_id = phy_id;
				if (switch_ctl_ioctl(SWITCH_CTL_PHY_AN_GET, &an) < 0)
					return -1;
				printf("[switch_ctl] main[%d]:switch_ctl phy %d autoNeg: %d\n", __LINE__, phy_id, an.speed_mask);
				return 0;
			} else if (argc >= 6 && !strcmp(argv[4], "set")) {
				struct phy_an_cmd an = {0};
				an.phy_id = phy_id;
				an.enable = 1;
				an.speed_mask = (uint32_t)strtoul(argv[5], NULL, 0);
				return switch_ctl_ioctl(SWITCH_CTL_PHY_AN_SET, &an);
			} else if (argc >= 5) {
				struct phy_an_cmd an = {0};
				an.phy_id = phy_id;
				an.enable = 1;
				an.speed_mask = (uint32_t)strtoul(argv[4], NULL, 0);
				return switch_ctl_ioctl(SWITCH_CTL_PHY_AN_SET, &an);
			}
			usage();
			return -1;
		}

		if (!strcmp(argv[3], "speed")) {
			if (argc < 7) {
				usage();
				return -1;
			}
			struct phy_speed_cmd sp;
			sp.phy_id = phy_id;
			sp.speed = (uint32_t)strtoul(argv[4], NULL, 0);
			sp.duplex = !strcmp(argv[6], "full") ? 1 : 0;
			if (switch_ctl_ioctl(SWITCH_CTL_PHY_SPEED_DUP, &sp) < 0) {
				fprintf(stderr, "[switch_ctl] main[%d]:switch_ctl phy speed error\n", __LINE__);
				return -1;
			}
			return 0;
		}

		if (!strcmp(argv[3], "w")) {
			if (argc < 6) {
				usage();
				return -1;
			}
			struct phy_reg_cmd pr;
			pr.phy_id = phy_id;
			pr.addr = (uint32_t)strtoul(argv[4], NULL, 16);
			pr.val = (uint16_t)strtoul(argv[5], NULL, 16);
			if (switch_ctl_ioctl(SWITCH_CTL_PHY_REG_W, &pr) < 0) {
				fprintf(stderr, "[switch_ctl] main[%d]:switch_ctl phy reg w error\n", __LINE__);
				return -1;
			}
			return 0;
		}

		if (!strcmp(argv[3], "r")) {
			if (argc < 5) {
				usage();
				return -1;
			}
			struct phy_reg_cmd pr = {0};
			pr.phy_id = phy_id;
			pr.addr = (uint32_t)strtoul(argv[4], NULL, 16);
			if (switch_ctl_ioctl(SWITCH_CTL_PHY_REG_R, &pr) < 0) {
				fprintf(stderr, "[switch_ctl] main[%d]:switch_ctl phy reg r error\n", __LINE__);
				return -1;
			}
			printf("[switch_ctl] main[%d]:switch_ctl phy %d r reg 0x%x value 0x%x\n", __LINE__, phy_id, pr.addr, pr.val);
			return 0;
		}

		if (!strcmp(argv[3], "game") && argc >= 5 && !strcmp(argv[4], "set")) {
			struct phy_game_cmd g;
			g.phy_id = phy_id;
			return switch_ctl_ioctl(SWITCH_CTL_PHY_GAME_SET, &g);
		}
	}

	usage();
	return -1;
}
