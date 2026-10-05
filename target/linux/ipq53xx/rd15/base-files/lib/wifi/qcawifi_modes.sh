#!/bin/sh
#
# Shared Qualcomm QSDK Direct Connect Wi-Fi Mode and Generation Helper
# Used by /lib/wifi/hostapd_config.sh and /lib/netifd/wireless/mac80211.sh
#

qcawifi_get_ht40_capab() {
	local band="$1"
	local ch="$2"

	if [ "$band" = "5g" ]; then
		case "$ch" in
			36|44|52|60|100|108|116|124|132|140|149|157)
				echo "[HT40+] [SHORT-GI-40]"
				;;
			40|48|56|64|104|112|120|128|136|144|153|161)
				echo "[HT40-] [SHORT-GI-40]"
				;;
			165)
				echo ""
				;;
			*)
				echo "[HT40+] [SHORT-GI-40]"
				;;
		esac
	else
		case "$ch" in
			8|9|10|11|12|13)
				echo "[HT40-] [SHORT-GI-40]"
				;;
			*)
				echo "[HT40+] [SHORT-GI-40]"
				;;
		esac
	fi
}

qcawifi_get_40mhz_center() {
	local band="$1"
	local ch="$2"

	if [ "$band" = "5g" ]; then
		case "$ch" in
			36|44|52|60|100|108|116|124|132|140|149|157)
				echo "$((ch + 2))"
				;;
			40|48|56|64|104|112|120|128|136|144|153|161)
				echo "$((ch - 2))"
				;;
			auto|0)
				echo "38"
				;;
			*)
				echo "$((ch + 2))"
				;;
		esac
	else
		case "$ch" in
			8|9|10|11|12|13)
				echo "$((ch - 2))"
				;;
			auto|0)
				echo "3"
				;;
			*)
				echo "$((ch + 2))"
				;;
		esac
	fi
}

qcawifi_get_80mhz_center() {
	local ch="$1"
	case "$ch" in
		36|40|44|48) echo "42" ;;
		52|56|60|64) echo "58" ;;
		100|104|108|112) echo "106" ;;
		116|120|124|128) echo "122" ;;
		132|136|140|144) echo "138" ;;
		149|153|157|161) echo "155" ;;
		*) echo "42" ;;
	esac
}

qcawifi_get_160mhz_center() {
	local ch="$1"
	case "$ch" in
		36|40|44|48|52|56|60|64) echo "50" ;;
		100|104|108|112|116|120|124|128) echo "114" ;;
		149|153|157|161|165|169|173|177) echo "163" ;;
		*) echo "50" ;;
	esac
}

qcawifi_eval_modes() {
	local band="$1"
	local hwmode="$2"
	local htmode="$3"
	local dev="$4"
	local ifname="$5"
	local channel="$6"

	# Auto-resolve empty htmode
	if [ -z "$htmode" ]; then
		case "$hwmode" in
			11g|11b|11bg|11a)
				htmode="NOHT"
				;;
			*be*)
				[ "$band" = "5g" ] && htmode="EHT160" || htmode="EHT40"
				;;
			*ax*)
				[ "$band" = "5g" ] && htmode="HE160" || htmode="HE40"
				;;
			*ac*)
				htmode="VHT80"
				;;
			*n*)
				htmode="HT40"
				;;
			*)
				[ "$band" = "5g" ] && htmode="EHT160" || htmode="EHT40"
				;;
		esac
	fi

	QC_HTMODE="$htmode"
	QC_IS_BE=0
	QC_IS_AX=0
	QC_IS_AC=0
	QC_IS_N=0

	# 1. Check htmode first (standard OpenWrt LuCI way)
	case "$htmode" in
		*EHT*|*eht*)
			QC_IS_BE=1; QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1
			;;
		*HE*|*he*)
			QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1
			;;
		*VHT*|*vht*)
			QC_IS_AC=1; QC_IS_N=1
			;;
		NOHT|noht|NONE|none)
			QC_IS_BE=0; QC_IS_AX=0; QC_IS_AC=0; QC_IS_N=0
			;;
		*HT*|*ht*)
			QC_IS_N=1
			;;
		*)
			case "$hwmode" in
				*be*)
					QC_IS_BE=1; QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1
					;;
				*ax*)
					QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1
					;;
				*ac*)
					QC_IS_AC=1; QC_IS_N=1
					;;
				11na|11ng|*n*)
					QC_IS_N=1
					;;
				11a|11g|11b|11bg)
					if [ "$htmode" = "160" ]; then
						[ "$band" = "5g" ] && { QC_IS_BE=1; QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1; }
					elif [ "$htmode" = "80" ]; then
						[ "$band" = "5g" ] && { QC_IS_BE=1; QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1; }
					elif [ "$htmode" = "40" ] || [ "$htmode" = "20" ]; then
						QC_IS_N=1
					fi
					;;
				*)
					[ "$band" = "5g" ] && { QC_IS_BE=1; QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1; } || { QC_IS_BE=1; QC_IS_AX=1; QC_IS_N=1; }
					;;
			esac
			;;
	esac

	# 2. Check if hwmode explicitly requests a newer generation
	case "$hwmode" in
		*be*)
			QC_IS_BE=1; QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1
			;;
		*ax*)
			[ "$QC_IS_BE" -eq 0 ] && { QC_IS_AX=1; QC_IS_AC=1; QC_IS_N=1; }
			;;
		*ac*)
			[ "$QC_IS_BE" -eq 0 ] && [ "$QC_IS_AX" -eq 0 ] && { QC_IS_AC=1; QC_IS_N=1; }
			;;
	esac

	# 3. Determine driver mode for cfg80211tool
	if [ "$dev" = "radio0" ] || [ "$band" = "2g" ] || [ "${ifname#ath0}" != "$ifname" ]; then
		local ext_2g_40="PLUS"
		case "$channel" in
			8|9|10|11|12|13) ext_2g_40="MINUS" ;;
			*) ext_2g_40="PLUS" ;;
		esac

		if [ "$QC_IS_BE" -eq 1 ]; then
			case "$htmode" in
				*40*) QC_DRIVER_MODE="11GEHT40${ext_2g_40}" ;;
				*)    QC_DRIVER_MODE="11GEHT20" ;;
			esac
		elif [ "$QC_IS_AX" -eq 1 ]; then
			case "$htmode" in
				*40*) QC_DRIVER_MODE="11GHE40${ext_2g_40}" ;;
				*)    QC_DRIVER_MODE="11GHE20" ;;
			esac
		elif [ "$QC_IS_N" -eq 1 ]; then
			case "$htmode" in
				*40*) QC_DRIVER_MODE="11NGHT40${ext_2g_40}" ;;
				*)    QC_DRIVER_MODE="11NGHT20" ;;
			esac
		else
			[ "$hwmode" = "11b" ] && QC_DRIVER_MODE="11B" || QC_DRIVER_MODE="11G"
		fi
	else
		# 5 GHz
		local ext_40="PLUS"
		case "$channel" in
			40|48|56|64|104|112|120|128|136|144|153|161) ext_40="MINUS" ;;
			*) ext_40="PLUS" ;;
		esac

		if [ "$QC_IS_BE" -eq 1 ]; then
			case "$htmode" in
				*320*) QC_DRIVER_MODE="11AEHT320" ;;
				*160*) QC_DRIVER_MODE="11AEHT160" ;;
				*80*)  QC_DRIVER_MODE="11AEHT80" ;;
				*40*)  QC_DRIVER_MODE="11AEHT40${ext_40}" ;;
				*)     QC_DRIVER_MODE="11AEHT20" ;;
			esac
		elif [ "$QC_IS_AX" -eq 1 ]; then
			case "$htmode" in
				*160*) QC_DRIVER_MODE="11AHE160" ;;
				*80*)  QC_DRIVER_MODE="11AHE80" ;;
				*40*)  QC_DRIVER_MODE="11AHE40${ext_40}" ;;
				*)     QC_DRIVER_MODE="11AHE20" ;;
			esac
		elif [ "$QC_IS_AC" -eq 1 ]; then
			case "$htmode" in
				*160*) QC_DRIVER_MODE="11ACVHT160" ;;
				*80*)  QC_DRIVER_MODE="11ACVHT80" ;;
				*40*)  QC_DRIVER_MODE="11ACVHT40${ext_40}" ;;
				*)     QC_DRIVER_MODE="11ACVHT20" ;;
			esac
		elif [ "$QC_IS_N" -eq 1 ]; then
			case "$htmode" in
				*40*) QC_DRIVER_MODE="11NAHT40${ext_40}" ;;
				*)    QC_DRIVER_MODE="11NAHT20" ;;
			esac
		else
			QC_DRIVER_MODE="11A"
		fi
	fi
}

qcawifi_get_target_mode() {
	local dev="$1"
	local ifname="$2"
	local band="$3"
	local hwmode="$4"
	local htmode="$5"
	local channel="$6"

	qcawifi_eval_modes "$band" "$hwmode" "$htmode" "$dev" "$ifname" "$channel"
	echo "$QC_DRIVER_MODE"
}
