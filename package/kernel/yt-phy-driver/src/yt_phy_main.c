// SPDX-License-Identifier: GPL-2.0+
/*
 * Motorcomm YT8821 2.5G Ethernet PHY driver with sysfs compatibility.
 *
 * Based on Linux upstream drivers/net/phy/motorcomm.c
 * Author: Frank Sae <Frank.Sae@motor-comm.com>
 * Author: Peter Geis <pgwipeout@gmail.com>
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/phy.h>
#include <linux/bitfield.h>
#include <linux/netdevice.h>
#include <linux/kobject.h>
#include <linux/sysfs.h>
#include <linux/string.h>
#include <linux/uaccess.h>

#define PHY_ID_YT8821				0x4f51ea19

#define YTPHY_PAGE_SELECT			0x1e
#define YTPHY_PAGE_DATA				0x1f

#define YT8521_REG_SPACE_SELECT_REG		0xa000
#define YT8521_RSSR_SPACE_MASK			GENMASK(1, 0)
#define YT8521_RSSR_FIBER_SPACE			0x1
#define YT8521_RSSR_UTP_SPACE			0x2

#define YT8521_CHIP_CONFIG_REG			0xa001
#define YT8521_CCR_SW_RST			BIT(15)
#define YT8521_CCR_MODE_SEL_MASK		GENMASK(2, 0)

#define YT8521_EXTREG_SLEEP_CONTROL1_REG	0x27
#define YT8521_ESC1R_SLEEP_SW			BIT(15)

#define YTPHY_SPECIFIC_STATUS_REG		0x11
#define YTPHY_SSR_SPEED_MASK			((0x3 << 14) | BIT(9))
#define YTPHY_SSR_SPEED_10M			((0x0 << 14))
#define YTPHY_SSR_SPEED_100M			((0x1 << 14))
#define YTPHY_SSR_SPEED_1000M			((0x2 << 14))
#define YTPHY_SSR_SPEED_2500M			((0x0 << 14) | BIT(9))
#define YTPHY_SSR_DUPLEX			BIT(13)
#define YTPHY_SSR_PAGE_RECEIVED			BIT(12)
#define YTPHY_SSR_LINK				BIT(10)

#define YTPHY_WOL_CONFIG_REG			0x8201
#define YTPHY_WCR_ENABLE			BIT(3)

#define YT8821_SDS_EXT_CSR_CTRL_REG		0x23
#define YT8821_SDS_EXT_CSR_VCO_LDO_EN		BIT(15)
#define YT8821_SDS_EXT_CSR_VCO_BIAS_LPF_EN	BIT(8)

#define YT8821_UTP_EXT_PI_CTRL_REG		0x56
#define YT8821_UTP_EXT_PI_RST_N_FIFO		BIT(5)
#define YT8821_UTP_EXT_PI_TX_CLK_SEL_AFE	BIT(4)
#define YT8821_UTP_EXT_PI_RX_CLK_3_SEL_AFE	BIT(3)
#define YT8821_UTP_EXT_PI_RX_CLK_2_SEL_AFE	BIT(2)
#define YT8821_UTP_EXT_PI_RX_CLK_1_SEL_AFE	BIT(1)
#define YT8821_UTP_EXT_PI_RX_CLK_0_SEL_AFE	BIT(0)

#define YT8821_UTP_EXT_VCT_CFG6_CTRL_REG	0x97
#define YT8821_UTP_EXT_FECHO_AMP_TH_HUGE	GENMASK(15, 8)

#define YT8821_UTP_EXT_ECHO_CTRL_REG		0x336
#define YT8821_UTP_EXT_TRACE_LNG_GAIN_THR_1000	GENMASK(14, 8)

#define YT8821_UTP_EXT_GAIN_CTRL_REG		0x340
#define YT8821_UTP_EXT_TRACE_MED_GAIN_THR_1000	GENMASK(6, 0)

#define YT8821_UTP_EXT_RPDN_CTRL_REG		0x34e
#define YT8821_UTP_EXT_RPDN_BP_FFE_LNG_2500	BIT(15)
#define YT8821_UTP_EXT_RPDN_BP_FFE_SHT_2500	BIT(7)
#define YT8821_UTP_EXT_RPDN_IPR_SHT_2500	GENMASK(6, 0)

#define YT8821_UTP_EXT_TH_20DB_2500_CTRL_REG	0x36a
#define YT8821_UTP_EXT_TH_20DB_2500		GENMASK(15, 0)

#define YT8821_UTP_EXT_TRACE_CTRL_REG		0x372
#define YT8821_UTP_EXT_TRACE_LNG_GAIN_THE_2500	GENMASK(14, 8)
#define YT8821_UTP_EXT_TRACE_MED_GAIN_THE_2500	GENMASK(6, 0)

#define YT8821_UTP_EXT_ALPHA_IPR_CTRL_REG	0x374
#define YT8821_UTP_EXT_ALPHA_SHT_2500		GENMASK(14, 8)
#define YT8821_UTP_EXT_IPR_LNG_2500		GENMASK(6, 0)

#define YT8821_UTP_EXT_PLL_CTRL_REG		0x450
#define YT8821_UTP_EXT_PLL_SPARE_CFG		GENMASK(7, 0)

#define YT8821_UTP_EXT_DAC_IMID_CH_2_3_CTRL_REG	0x466
#define YT8821_UTP_EXT_DAC_IMID_CH_3_10_ORG	GENMASK(14, 8)
#define YT8821_UTP_EXT_DAC_IMID_CH_2_10_ORG	GENMASK(6, 0)

#define YT8821_UTP_EXT_DAC_IMID_CH_0_1_CTRL_REG	0x467
#define YT8821_UTP_EXT_DAC_IMID_CH_1_10_ORG	GENMASK(14, 8)
#define YT8821_UTP_EXT_DAC_IMID_CH_0_10_ORG	GENMASK(6, 0)

#define YT8821_UTP_EXT_DAC_IMSB_CH_2_3_CTRL_REG	0x468
#define YT8821_UTP_EXT_DAC_IMSB_CH_3_10_ORG	GENMASK(14, 8)
#define YT8821_UTP_EXT_DAC_IMSB_CH_2_10_ORG	GENMASK(6, 0)

#define YT8821_UTP_EXT_DAC_IMSB_CH_0_1_CTRL_REG	0x469
#define YT8821_UTP_EXT_DAC_IMSB_CH_1_10_ORG	GENMASK(14, 8)
#define YT8821_UTP_EXT_DAC_IMSB_CH_0_10_ORG	GENMASK(6, 0)

#define YT8821_UTP_EXT_MU_COARSE_FR_CTRL_REG	0x4b3
#define YT8821_UTP_EXT_MU_COARSE_FR_F_FFE	GENMASK(14, 12)
#define YT8821_UTP_EXT_MU_COARSE_FR_F_FBE	GENMASK(10, 8)

#define YT8821_UTP_EXT_MU_FINE_FR_CTRL_REG	0x4b5
#define YT8821_UTP_EXT_MU_FINE_FR_F_FFE		GENMASK(14, 12)
#define YT8821_UTP_EXT_MU_FINE_FR_F_FBE		GENMASK(10, 8)

#define YT8821_UTP_EXT_VGA_LPF1_CAP_CTRL_REG	0x4d2
#define YT8821_UTP_EXT_VGA_LPF1_CAP_OTHER	GENMASK(7, 4)
#define YT8821_UTP_EXT_VGA_LPF1_CAP_2500	GENMASK(3, 0)

#define YT8821_UTP_EXT_VGA_LPF2_CAP_CTRL_REG	0x4d3
#define YT8821_UTP_EXT_VGA_LPF2_CAP_OTHER	GENMASK(7, 4)
#define YT8821_UTP_EXT_VGA_LPF2_CAP_2500	GENMASK(3, 0)

#define YT8821_UTP_EXT_TXGE_NFR_FR_THP_CTRL_REG	0x660
#define YT8821_UTP_EXT_NFR_TX_ABILITY		BIT(3)

#define YT8821_CHIP_MODE_AUTO_BX2500_SGMII	0
#define YT8821_CHIP_MODE_FORCE_BX2500		1

/* Forward declarations */
static struct phy_device *g_yt8821_phydev;

static int ytphy_modify_ext(struct phy_device *phydev, u16 regnum, u16 mask, u16 set)
{
	int ret;

	ret = __phy_write(phydev, YTPHY_PAGE_SELECT, regnum);
	if (ret < 0)
		return ret;

	return __phy_modify(phydev, YTPHY_PAGE_DATA, mask, set);
}

static int ytphy_read_ext(struct phy_device *phydev, u16 regnum)
{
	int ret;

	ret = __phy_write(phydev, YTPHY_PAGE_SELECT, regnum);
	if (ret < 0)
		return ret;

	return __phy_read(phydev, YTPHY_PAGE_DATA);
}

static int ytphy_write_ext(struct phy_device *phydev, u16 regnum, u16 val)
{
	int ret;

	ret = __phy_write(phydev, YTPHY_PAGE_SELECT, regnum);
	if (ret < 0)
		return ret;

	return __phy_write(phydev, YTPHY_PAGE_DATA, val);
}

static int ytphy_modify_ext_with_lock(struct phy_device *phydev, u16 regnum, u16 mask, u16 set)
{
	int ret;

	mutex_lock(&phydev->mdio.bus->mdio_lock);
	ret = ytphy_modify_ext(phydev, regnum, mask, set);
	mutex_unlock(&phydev->mdio.bus->mdio_lock);

	return ret;
}

static int ytphy_read_ext_with_lock(struct phy_device *phydev, u16 regnum)
{
	int ret;

	mutex_lock(&phydev->mdio.bus->mdio_lock);
	ret = ytphy_read_ext(phydev, regnum);
	mutex_unlock(&phydev->mdio.bus->mdio_lock);

	return ret;
}

static int ytphy_write_ext_with_lock(struct phy_device *phydev, u16 regnum, u16 val)
{
	int ret;

	mutex_lock(&phydev->mdio.bus->mdio_lock);
	ret = ytphy_write_ext(phydev, regnum, val);
	mutex_unlock(&phydev->mdio.bus->mdio_lock);

	return ret;
}

static int yt8521_read_page(struct phy_device *phydev)
{
	int ret;

	ret = ytphy_read_ext_with_lock(phydev, YT8521_REG_SPACE_SELECT_REG);
	if (ret < 0)
		return ret;

	return FIELD_GET(YT8521_RSSR_SPACE_MASK, ret);
}

static int yt8521_write_page(struct phy_device *phydev, int page)
{
	int mask = YT8521_RSSR_SPACE_MASK;
	int set = FIELD_PREP(YT8521_RSSR_SPACE_MASK, page);

	return ytphy_modify_ext_with_lock(phydev, YT8521_REG_SPACE_SELECT_REG,
					  mask, set);
}

static int yt8521_modify_bmcr_paged(struct phy_device *phydev, int page,
				    u16 mask, u16 set)
{
	int old_page;
	int ret = 0;

	old_page = phy_select_page(phydev, page);
	if (old_page < 0)
		goto err_restore_page;

	ret = __phy_modify(phydev, MII_BMCR, mask, set);

err_restore_page:
	return phy_restore_page(phydev, old_page, ret);
}

static int yt8521_aneg_done_paged(struct phy_device *phydev, int page)
{
	int old_page;
	int ret = 0;

	old_page = phy_select_page(phydev, page);
	if (old_page < 0)
		goto err_restore_page;

	ret = __phy_read(phydev, MII_BMSR);
	if (ret > 0)
		ret = (ret & BMSR_ANEGCOMPLETE) ? 1 : 0;

err_restore_page:
	return phy_restore_page(phydev, old_page, ret);
}

static int yt8821_aneg_done(struct phy_device *phydev)
{
	return yt8521_aneg_done_paged(phydev, YT8521_RSSR_UTP_SPACE);
}

static int yt8821_get_features(struct phy_device *phydev)
{
	int ret;

	ret = genphy_c45_pma_read_abilities(phydev);
	if (ret < 0)
		return ret;

	return genphy_read_abilities(phydev);
}

static int yt8821_serdes_init(struct phy_device *phydev)
{
	int old_page;
	int ret = 0;
	u16 mask;
	u16 set;

	old_page = phy_select_page(phydev, YT8521_RSSR_FIBER_SPACE);
	if (old_page < 0) {
		phydev_err(phydev, "Failed to select fiber page: %d\n", old_page);
		goto err_restore_page;
	}

	ret = __phy_modify(phydev, MII_BMCR, BMCR_ANENABLE, 0);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_SDS_EXT_CSR_VCO_LDO_EN |
	       YT8821_SDS_EXT_CSR_VCO_BIAS_LPF_EN;
	set = YT8821_SDS_EXT_CSR_VCO_LDO_EN;
	ret = ytphy_modify_ext(phydev, YT8821_SDS_EXT_CSR_CTRL_REG, mask, set);

err_restore_page:
	return phy_restore_page(phydev, old_page, ret);
}

static int yt8821_utp_init(struct phy_device *phydev)
{
	int old_page;
	int ret = 0;
	u16 mask;
	u16 save;
	u16 set;

	old_page = phy_select_page(phydev, YT8521_RSSR_UTP_SPACE);
	if (old_page < 0) {
		phydev_err(phydev, "Failed to select UTP page: %d\n", old_page);
		goto err_restore_page;
	}

	mask = YT8821_UTP_EXT_RPDN_BP_FFE_LNG_2500 |
	       YT8821_UTP_EXT_RPDN_BP_FFE_SHT_2500 |
	       YT8821_UTP_EXT_RPDN_IPR_SHT_2500;
	set = YT8821_UTP_EXT_RPDN_BP_FFE_LNG_2500 |
	      YT8821_UTP_EXT_RPDN_BP_FFE_SHT_2500;
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_RPDN_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_VGA_LPF1_CAP_OTHER |
	       YT8821_UTP_EXT_VGA_LPF1_CAP_2500;
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_VGA_LPF1_CAP_CTRL_REG, mask, 0);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_VGA_LPF2_CAP_OTHER |
	       YT8821_UTP_EXT_VGA_LPF2_CAP_2500;
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_VGA_LPF2_CAP_CTRL_REG, mask, 0);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_TRACE_LNG_GAIN_THE_2500 |
	       YT8821_UTP_EXT_TRACE_MED_GAIN_THE_2500;
	set = FIELD_PREP(YT8821_UTP_EXT_TRACE_LNG_GAIN_THE_2500, 0x5a) |
	      FIELD_PREP(YT8821_UTP_EXT_TRACE_MED_GAIN_THE_2500, 0x3c);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_TRACE_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_IPR_LNG_2500;
	set = FIELD_PREP(YT8821_UTP_EXT_IPR_LNG_2500, 0x6c);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_ALPHA_IPR_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_TRACE_LNG_GAIN_THR_1000;
	set = FIELD_PREP(YT8821_UTP_EXT_TRACE_LNG_GAIN_THR_1000, 0x2a);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_ECHO_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_TRACE_MED_GAIN_THR_1000;
	set = FIELD_PREP(YT8821_UTP_EXT_TRACE_MED_GAIN_THR_1000, 0x22);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_GAIN_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_TH_20DB_2500;
	set = FIELD_PREP(YT8821_UTP_EXT_TH_20DB_2500, 0x8000);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_TH_20DB_2500_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_MU_COARSE_FR_F_FFE |
	       YT8821_UTP_EXT_MU_COARSE_FR_F_FBE;
	set = FIELD_PREP(YT8821_UTP_EXT_MU_COARSE_FR_F_FFE, 0x7) |
	      FIELD_PREP(YT8821_UTP_EXT_MU_COARSE_FR_F_FBE, 0x7);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_MU_COARSE_FR_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_MU_FINE_FR_F_FFE |
	       YT8821_UTP_EXT_MU_FINE_FR_F_FBE;
	set = FIELD_PREP(YT8821_UTP_EXT_MU_FINE_FR_F_FFE, 0x2) |
	      FIELD_PREP(YT8821_UTP_EXT_MU_FINE_FR_F_FBE, 0x2);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_MU_FINE_FR_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	ret = ytphy_read_ext(phydev, YT8821_UTP_EXT_PI_CTRL_REG);
	if (ret < 0)
		goto err_restore_page;
	save = ret;

	mask = YT8821_UTP_EXT_PI_TX_CLK_SEL_AFE |
	       YT8821_UTP_EXT_PI_RX_CLK_3_SEL_AFE |
	       YT8821_UTP_EXT_PI_RX_CLK_2_SEL_AFE |
	       YT8821_UTP_EXT_PI_RX_CLK_1_SEL_AFE |
	       YT8821_UTP_EXT_PI_RX_CLK_0_SEL_AFE;
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_PI_CTRL_REG, mask, 0);
	if (ret < 0)
		goto err_restore_page;

	ret = ytphy_write_ext(phydev, YT8821_UTP_EXT_PI_CTRL_REG, save);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_FECHO_AMP_TH_HUGE;
	set = FIELD_PREP(YT8821_UTP_EXT_FECHO_AMP_TH_HUGE, 0x38);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_VCT_CFG6_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_NFR_TX_ABILITY;
	set = YT8821_UTP_EXT_NFR_TX_ABILITY;
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_TXGE_NFR_FR_THP_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_PLL_SPARE_CFG;
	set = FIELD_PREP(YT8821_UTP_EXT_PLL_SPARE_CFG, 0xe9);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_PLL_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_DAC_IMID_CH_3_10_ORG |
	       YT8821_UTP_EXT_DAC_IMID_CH_2_10_ORG;
	set = FIELD_PREP(YT8821_UTP_EXT_DAC_IMID_CH_3_10_ORG, 0x64) |
	      FIELD_PREP(YT8821_UTP_EXT_DAC_IMID_CH_2_10_ORG, 0x64);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_DAC_IMID_CH_2_3_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_DAC_IMID_CH_1_10_ORG |
	       YT8821_UTP_EXT_DAC_IMID_CH_0_10_ORG;
	set = FIELD_PREP(YT8821_UTP_EXT_DAC_IMID_CH_1_10_ORG, 0x64) |
	      FIELD_PREP(YT8821_UTP_EXT_DAC_IMID_CH_0_10_ORG, 0x64);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_DAC_IMID_CH_0_1_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_DAC_IMSB_CH_3_10_ORG |
	       YT8821_UTP_EXT_DAC_IMSB_CH_2_10_ORG;
	set = FIELD_PREP(YT8821_UTP_EXT_DAC_IMSB_CH_3_10_ORG, 0x64) |
	      FIELD_PREP(YT8821_UTP_EXT_DAC_IMSB_CH_2_10_ORG, 0x64);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_DAC_IMSB_CH_2_3_CTRL_REG, mask, set);
	if (ret < 0)
		goto err_restore_page;

	mask = YT8821_UTP_EXT_DAC_IMSB_CH_1_10_ORG |
	       YT8821_UTP_EXT_DAC_IMSB_CH_0_10_ORG;
	set = FIELD_PREP(YT8821_UTP_EXT_DAC_IMSB_CH_1_10_ORG, 0x64) |
	      FIELD_PREP(YT8821_UTP_EXT_DAC_IMSB_CH_0_10_ORG, 0x64);
	ret = ytphy_modify_ext(phydev, YT8821_UTP_EXT_DAC_IMSB_CH_0_1_CTRL_REG, mask, set);

err_restore_page:
	return phy_restore_page(phydev, old_page, ret);
}

static int yt8821_auto_sleep_config(struct phy_device *phydev, bool enable)
{
	int old_page;
	int ret = 0;

	old_page = phy_select_page(phydev, YT8521_RSSR_UTP_SPACE);
	if (old_page < 0) {
		phydev_err(phydev, "Failed to select UTP page: %d\n", old_page);
		goto err_restore_page;
	}

	ret = ytphy_modify_ext(phydev, YT8521_EXTREG_SLEEP_CONTROL1_REG,
			       YT8521_ESC1R_SLEEP_SW, enable ? 1 : 0);

err_restore_page:
	return phy_restore_page(phydev, old_page, ret);
}

static int yt8821_soft_reset(struct phy_device *phydev)
{
	return ytphy_modify_ext_with_lock(phydev, YT8521_CHIP_CONFIG_REG,
					  YT8521_CCR_SW_RST, 0);
}

static int yt8821_config_init(struct phy_device *phydev)
{
	u8 mode = YT8821_CHIP_MODE_AUTO_BX2500_SGMII;
	int ret;
	u16 set;

	if (phydev->interface == PHY_INTERFACE_MODE_2500BASEX)
		mode = YT8821_CHIP_MODE_FORCE_BX2500;

	set = FIELD_PREP(YT8521_CCR_MODE_SEL_MASK, mode);
	ret = ytphy_modify_ext_with_lock(phydev, YT8521_CHIP_CONFIG_REG,
					 YT8521_CCR_MODE_SEL_MASK, set);
	if (ret < 0)
		return ret;

	ret = yt8821_serdes_init(phydev);
	if (ret < 0)
		return ret;

	ret = yt8821_utp_init(phydev);
	if (ret < 0)
		return ret;

	/* disable auto sleep */
	ret = yt8821_auto_sleep_config(phydev, false);
	if (ret < 0)
		return ret;

	/* soft reset */
	return yt8821_soft_reset(phydev);
}

static void yt8821_adjust_status(struct phy_device *phydev, int val)
{
	int speed, duplex;
	int speed_mode;

	duplex = FIELD_GET(YTPHY_SSR_DUPLEX, val);
	speed_mode = val & YTPHY_SSR_SPEED_MASK;
	switch (speed_mode) {
	case YTPHY_SSR_SPEED_10M:
		speed = SPEED_10;
		break;
	case YTPHY_SSR_SPEED_100M:
		speed = SPEED_100;
		break;
	case YTPHY_SSR_SPEED_1000M:
		speed = SPEED_1000;
		break;
	case YTPHY_SSR_SPEED_2500M:
		speed = SPEED_2500;
		break;
	default:
		speed = SPEED_UNKNOWN;
		break;
	}

	phydev->speed = speed;
	phydev->duplex = duplex;
}

static void yt8821_update_interface(struct phy_device *phydev)
{
	if (!phydev->link)
		return;

	switch (phydev->speed) {
	case SPEED_2500:
		phydev->interface = PHY_INTERFACE_MODE_2500BASEX;
		break;
	case SPEED_1000:
	case SPEED_100:
	case SPEED_10:
		phydev->interface = PHY_INTERFACE_MODE_SGMII;
		break;
	default:
		phydev_warn(phydev, "phy speed err :%d\n", phydev->speed);
		break;
	}
}

static int yt8821_read_status(struct phy_device *phydev)
{
	int link;
	int ret;
	int val;

	ret = ytphy_write_ext_with_lock(phydev, YT8521_REG_SPACE_SELECT_REG,
					YT8521_RSSR_UTP_SPACE);
	if (ret < 0)
		return ret;

	ret = genphy_read_status(phydev);
	if (ret < 0)
		return ret;

	if (phydev->autoneg_complete) {
		ret = genphy_c45_read_lpa(phydev);
		if (ret < 0)
			return ret;
	}

	ret = phy_read(phydev, YTPHY_SPECIFIC_STATUS_REG);
	if (ret < 0)
		return ret;

	val = ret;
	link = val & YTPHY_SSR_LINK;
	if (link)
		yt8821_adjust_status(phydev, val);

	if (link) {
		if (phydev->link == 0)
			phydev_info(phydev, "YT8821, addr: %d, link up, speed: %d\n",
				    phydev->mdio.addr, phydev->speed);
		phydev->link = 1;
	} else {
		if (phydev->link == 1)
			phydev_info(phydev, "YT8821, addr: %d, link down\n",
				    phydev->mdio.addr);
		phydev->link = 0;
	}

	val = ytphy_read_ext_with_lock(phydev, YT8521_CHIP_CONFIG_REG);
	if (val < 0)
		return val;

	if (FIELD_GET(YT8521_CCR_MODE_SEL_MASK, val) ==
	    YT8821_CHIP_MODE_AUTO_BX2500_SGMII)
		yt8821_update_interface(phydev);

	return 0;
}

static int yt8821_modify_utp_fiber_bmcr(struct phy_device *phydev, u16 mask, u16 set)
{
	int ret;

	ret = yt8521_modify_bmcr_paged(phydev, YT8521_RSSR_UTP_SPACE, mask, set);
	if (ret < 0)
		return ret;

	return yt8521_modify_bmcr_paged(phydev, YT8521_RSSR_FIBER_SPACE, mask, set);
}

static int yt8821_suspend(struct phy_device *phydev)
{
	return yt8821_modify_utp_fiber_bmcr(phydev, 0, BMCR_PDOWN);
}

static int yt8821_resume(struct phy_device *phydev)
{
	int ret;

	ret = yt8821_auto_sleep_config(phydev, false);
	if (ret < 0)
		return ret;

	return yt8821_modify_utp_fiber_bmcr(phydev, BMCR_PDOWN, 0);
}

static int yt8821_probe(struct phy_device *phydev)
{
	g_yt8821_phydev = phydev;
	phydev_info(phydev, "YT8821 2.5G PHY probed at addr 0x%02x\n", phydev->mdio.addr);
	return 0;
}

static void yt8821_remove(struct phy_device *phydev)
{
	if (g_yt8821_phydev == phydev)
		g_yt8821_phydev = NULL;
}

/*
 * Sysfs Compatibility Layer
 * Path: /sys/module/yt_phy_module/port_status/port0/
 */

static ssize_t power_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
	int val = 1;
	if (g_yt8821_phydev) {
		int bmcr = phy_read(g_yt8821_phydev, MII_BMCR);
		if (bmcr >= 0 && (bmcr & BMCR_PDOWN))
			val = 0;
	}
	return sprintf(buf, "%d\n", val);
}

static ssize_t power_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buf, size_t count)
{
	int val;
	if (kstrtoint(buf, 0, &val) == 0 && g_yt8821_phydev) {
		if (val == 0)
			yt8821_suspend(g_yt8821_phydev);
		else
			yt8821_resume(g_yt8821_phydev);
	}
	return count;
}

static ssize_t speed_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
	if (!g_yt8821_phydev || !g_yt8821_phydev->link)
		return sprintf(buf, "link:down\n");

	return sprintf(buf, "link:up speed:%d %s\n",
		       g_yt8821_phydev->speed,
		       g_yt8821_phydev->duplex == DUPLEX_FULL ? "full duplex" : "half duplex");
}

static ssize_t autoneg_show_speed(struct kobject *kobj, struct kobj_attribute *attr, char *buf, int speed)
{
	int enabled = 1;
	if (g_yt8821_phydev) {
		switch (speed) {
		case 10:
			enabled = linkmode_test_bit(ETHTOOL_LINK_MODE_10baseT_Full_BIT, g_yt8821_phydev->advertising) ||
			          linkmode_test_bit(ETHTOOL_LINK_MODE_10baseT_Half_BIT, g_yt8821_phydev->advertising);
			break;
		case 100:
			enabled = linkmode_test_bit(ETHTOOL_LINK_MODE_100baseT_Full_BIT, g_yt8821_phydev->advertising) ||
			          linkmode_test_bit(ETHTOOL_LINK_MODE_1000baseT_Half_BIT, g_yt8821_phydev->advertising);
			break;
		case 1000:
			enabled = linkmode_test_bit(ETHTOOL_LINK_MODE_1000baseT_Full_BIT, g_yt8821_phydev->advertising) ||
			          linkmode_test_bit(ETHTOOL_LINK_MODE_1000baseT_Half_BIT, g_yt8821_phydev->advertising);
			break;
		case 2500:
			enabled = linkmode_test_bit(ETHTOOL_LINK_MODE_2500baseT_Full_BIT, g_yt8821_phydev->advertising) ||
			          linkmode_test_bit(ETHTOOL_LINK_MODE_2500baseX_Full_BIT, g_yt8821_phydev->advertising);
			break;
		}
	}
	return sprintf(buf, "%d\n", enabled ? 1 : 0);
}

static ssize_t autoneg_store_speed(struct kobject *kobj, struct kobj_attribute *attr, const char *buf, size_t count, int speed)
{
	int val;
	if (kstrtoint(buf, 0, &val) == 0 && g_yt8821_phydev) {
		bool enable = (val != 0);
		switch (speed) {
		case 10:
			linkmode_mod_bit(ETHTOOL_LINK_MODE_10baseT_Full_BIT, g_yt8821_phydev->advertising, enable);
			linkmode_mod_bit(ETHTOOL_LINK_MODE_10baseT_Half_BIT, g_yt8821_phydev->advertising, enable);
			break;
		case 100:
			linkmode_mod_bit(ETHTOOL_LINK_MODE_100baseT_Full_BIT, g_yt8821_phydev->advertising, enable);
			linkmode_mod_bit(ETHTOOL_LINK_MODE_100baseT_Half_BIT, g_yt8821_phydev->advertising, enable);
			break;
		case 1000:
			linkmode_mod_bit(ETHTOOL_LINK_MODE_1000baseT_Full_BIT, g_yt8821_phydev->advertising, enable);
			linkmode_mod_bit(ETHTOOL_LINK_MODE_1000baseT_Half_BIT, g_yt8821_phydev->advertising, enable);
			break;
		case 2500:
			linkmode_mod_bit(ETHTOOL_LINK_MODE_2500baseT_Full_BIT, g_yt8821_phydev->advertising, enable);
			linkmode_mod_bit(ETHTOOL_LINK_MODE_2500baseX_Full_BIT, g_yt8821_phydev->advertising, enable);
			break;
		}
		phy_start_aneg(g_yt8821_phydev);
	}
	return count;
}

static ssize_t autoNeg_10_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
	return autoneg_show_speed(kobj, attr, buf, 10);
}
static ssize_t autoNeg_10_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buf, size_t count)
{
	return autoneg_store_speed(kobj, attr, buf, count, 10);
}

static ssize_t autoNeg_100_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
	return autoneg_show_speed(kobj, attr, buf, 100);
}
static ssize_t autoNeg_100_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buf, size_t count)
{
	return autoneg_store_speed(kobj, attr, buf, count, 100);
}

static ssize_t autoNeg_1000_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
	return autoneg_show_speed(kobj, attr, buf, 1000);
}
static ssize_t autoNeg_1000_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buf, size_t count)
{
	return autoneg_store_speed(kobj, attr, buf, count, 1000);
}

static ssize_t autoNeg_2500_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
	return autoneg_show_speed(kobj, attr, buf, 2500);
}
static ssize_t autoNeg_2500_store(struct kobject *kobj, struct kobj_attribute *attr, const char *buf, size_t count)
{
	return autoneg_store_speed(kobj, attr, buf, count, 2500);
}

static struct kobj_attribute attr_power = __ATTR_RW(power);
static struct kobj_attribute attr_speed = __ATTR_RO(speed);
static struct kobj_attribute attr_10_autoNeg = __ATTR(10_autoNeg, 0644, autoNeg_10_show, autoNeg_10_store);
static struct kobj_attribute attr_100_autoNeg = __ATTR(100_autoNeg, 0644, autoNeg_100_show, autoNeg_100_store);
static struct kobj_attribute attr_1000_autoNeg = __ATTR(1000_autoNeg, 0644, autoNeg_1000_show, autoNeg_1000_store);
static struct kobj_attribute attr_2500_autoNeg = __ATTR(2500_autoNeg, 0644, autoNeg_2500_show, autoNeg_2500_store);

static struct attribute *port0_attrs[] = {
	&attr_power.attr,
	&attr_speed.attr,
	&attr_10_autoNeg.attr,
	&attr_100_autoNeg.attr,
	&attr_1000_autoNeg.attr,
	&attr_2500_autoNeg.attr,
	NULL,
};

static struct attribute_group port0_attr_group = {
	.attrs = port0_attrs,
};

static struct kobject *port_status_kobj;
static struct kobject *port0_kobj;

static int yt_phy_sysfs_init(void)
{
	port_status_kobj = kobject_create_and_add("port_status", &THIS_MODULE->mkobj.kobj);
	if (!port_status_kobj)
		return -ENOMEM;

	port0_kobj = kobject_create_and_add("port0", port_status_kobj);
	if (!port0_kobj) {
		kobject_put(port_status_kobj);
		port_status_kobj = NULL;
		return -ENOMEM;
	}

	return sysfs_create_group(port0_kobj, &port0_attr_group);
}

static void yt_phy_sysfs_exit(void)
{
	if (port0_kobj) {
		sysfs_remove_group(port0_kobj, &port0_attr_group);
		kobject_put(port0_kobj);
		port0_kobj = NULL;
	}
	if (port_status_kobj) {
		kobject_put(port_status_kobj);
		port_status_kobj = NULL;
	}
}

static struct phy_driver yt_phy_drvs[] = {
	{
		PHY_ID_MATCH_EXACT(PHY_ID_YT8821),
		.name			= "YT8821 2.5Gbps PHY",
		.get_features		= yt8821_get_features,
		.probe			= yt8821_probe,
		.remove			= yt8821_remove,
		.read_page		= yt8521_read_page,
		.write_page		= yt8521_write_page,
		.config_aneg		= genphy_config_aneg,
		.aneg_done		= yt8821_aneg_done,
		.config_init		= yt8821_config_init,
		.read_status		= yt8821_read_status,
		.soft_reset		= yt8821_soft_reset,
		.suspend		= yt8821_suspend,
		.resume			= yt8821_resume,
	},
};

static int __init yt_phy_module_init(void)
{
	int ret;

	ret = phy_drivers_register(yt_phy_drvs, ARRAY_SIZE(yt_phy_drvs), THIS_MODULE);
	if (ret)
		return ret;

	ret = yt_phy_sysfs_init();
	if (ret)
		pr_warn("yt_phy_module: failed to init sysfs compatibility: %d\n", ret);

	pr_info("yt_phy_module: Motorcomm YT8821 PHY driver initialized\n");
	return 0;
}

static void __exit yt_phy_module_exit(void)
{
	yt_phy_sysfs_exit();
	phy_drivers_unregister(yt_phy_drvs, ARRAY_SIZE(yt_phy_drvs));
	pr_info("yt_phy_module: Motorcomm YT8821 PHY driver exited\n");
}

module_init(yt_phy_module_init);
module_exit(yt_phy_module_exit);

MODULE_DESCRIPTION("Motorcomm YT8821 2.5G Ethernet PHY Driver");
MODULE_AUTHOR("Frank Sae <Frank.Sae@motor-comm.com>");
MODULE_LICENSE("GPL");

static const struct mdio_device_id __maybe_unused yt_phy_tbl[] = {
	{ PHY_ID_MATCH_EXACT(PHY_ID_YT8821) },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(mdio, yt_phy_tbl);
