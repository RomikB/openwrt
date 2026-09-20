#!/bin/sh
#
# Copyright (c) 2019, 2022 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

dpp_operating_class_setup()
{
	htmode=$1
	channel=$2
	band=$3

	# select the operating class for 2.4GHz channels
	if [ $channel -ge 1 -a $channel -le 14 -a $band -ne 3 ]
	then
		case "$htmode" in
			HT40+)
				if [ $channel -lt 1 -a $channel -gt 9 ]
				then
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
				return 83
			;;
			HT40-)
				if [ $channel -lt 5 -a $channel -gt 13 ]
				then
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
				return 84
			;;
			HT40)
				if [ $channel -ge 1 -a $channel -le 9 ]
				then
					return 83
				elif [ $channel -ne 14 ]
				then
					return 84
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
			*)
				if [ $channel -eq 14 ]
				then
					return 82
				else
					return 81
				fi
			;;
		esac
	# select the operating class for 5GHz channels
	elif [ $channel -ge 36 -a $channel -le 169 -a $band -ne 3 ]
	then
		case "$htmode" in
			*HT40+)
				if [ $channel -eq 36 -o $channel -eq 44 ]
				then
					return 116
				elif [ $channel -eq 52 -o $channel -eq 60 ]
				then
					return 119
				elif [ $channel -eq 100 -o $channel -eq 108 -o $channel -eq 116 -o $channel -eq 124 -o $channel -eq 132 -o $channel -eq 140 ]
				then
					return 122
				elif [ $channel -eq 149 -o $channel -eq 157 ]
				then
					return 126
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
			*HT40-)
				if [ $channel -eq 40 -o $channel -eq 48 ]
				then
					return 117
				elif [ $channel -eq 56 -o $channel -eq 64 ]
				then
					return 120
				elif [ $channel -eq 104 -o $channel -eq 112 -o $channel -eq 120 -o $channel -eq 128 -o $channel -eq 136 -o $channel -eq 144 ]
				then
					return 123
				elif [ $channel -eq 153 -o $channel -eq 161 ]
				then
					return 127
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
			*HT40)
				if [ $channel -eq 36 -o $channel -eq 44 ]
				then
					return 116
				elif [ $channel -eq 40 -o $channel -eq 48 ]
				then
					return 117
				elif [ $channel -eq 52 -o $channel -eq 60 ]
				then
					return 119
				elif [ $channel -eq 56 -o $channel -eq 64 ]
				then
					return 120
				elif [ $channel -eq 100 -o $channel -eq 108 -o $channel -eq 116 -o $channel -eq 124 -o $channel -eq 132 -o $channel -eq 140 ]
				then
					return 122
				elif [ $channel -eq 104 -o $channel -eq 112 -o $channel -eq 120 -o $channel -eq 128 -o $channel -eq 136 -o $channel -eq 144 ]
				then
					return 123
				elif [ $channel -eq 149 -o $channel -eq 157 ]
				then
					return 126
				elif [ $channel -eq 153 -o $channel -eq 161 ]
				then
					return 127
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
			*HT80)	return 128;;
			*HT80_80) return 130;;
			*HT160)	return 129;;
			*)
				if [ $channel -eq 36 -o $channel -eq 40 -o $channel -eq 44 -o $channel -eq 48 ]
				then
					return 115
				elif [ $channel -eq 52 -o $channel -eq 56 -o $channel -eq 60 -o $channel -eq 64 ]
				then
					return 118
				elif [ $channel -eq 100 -o $channel -eq 104 -o $channel -eq 108 -o $channel -eq 112 -o $channel -eq 116 -o $channel -eq 120 -o $channel -eq 124 -o $channel -eq 128 -o $channel -eq 132 -o $channel -eq 136 -o $channel -eq 140 -o $channel -eq 144 ]
				then
					return 121
				elif [ $channel -eq 149 -o $channel -eq 153 -o $channel -eq 157 -o $channel -eq 161 ]
				then
					return 124
				elif [ $channel -eq 149 -o $channel -eq 153 -o $channel -eq 157 -o $channel -eq 161 -o $channel -eq 165 -o $channel -eq 169 ]
				then
					return 125
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
		esac
	# select the operating class for 6GHz channels
	elif [ $channel -ge 1 -a $channel -le 233 -a $band -eq 3 ]
	then
		case "$htmode" in
			*HT20)
				if [ $channel -eq 1 -o $channel -eq 5 -o $channel -eq 9 -o $channel -eq 13 -o $channel -eq 17 -o $channel -eq 21 -o $channel -eq 25 -o $channel -eq 29 -o $channel -eq 33 -o $channel -eq 37 -o $channel -eq 41 -o $channel -eq 45 -o $channel -eq 49 ]
				then
					return 131
				elif [ $channel -eq 53 -o $channel -eq 57 -o $channel -eq 61 -o $channel -eq 65 -o $channel -eq 69 -o $channel -eq 73 -o $channel -eq 77 -o $channel -eq 81 -o $channel -eq 85 -o $channel -eq 89 -o $channel -eq 93 -o $channel -eq 97 ]
				then
					return 131
				elif [ $channel -eq 101 -o $channel -eq 105 -o $channel -eq 109 -o $channel -eq 113 -o $channel -eq 117 -o $channel -eq 121 -o $channel -eq 125 -o $channel -eq 129 -o $channel -eq 133 -o $channel -eq 137 -o $channel -eq 141 -o $channel -eq 145 ]
				then
					return 131
				elif [ $channel -eq 149 -o $channel -eq 153 -o $channel -eq 157 -o $channel -eq 161 -o $channel -eq 165 -o $channel -eq 169 -o $channel -eq 173 -o $channel -eq 177 -o $channel -eq 181 -o $channel -eq 185 -o $channel -eq 189 -o $channel -eq 193 ]
				then
					return 131
				elif [ $channel -eq 197 -o $channel -eq 201 -o $channel -eq 205 -o $channel -eq 209 -o $channel -eq 213 -o $channel -eq 217 -o $channel -eq 221 -o $channel -eq 225 -o $channel -eq 229 -o $channel -eq 233 ]
				then
					return 131
				elif [ $channel -eq 2 ]
				then
					return 136
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
			*HT40)
				if [ $channel -eq 1 -o $channel -eq 9 -o $channel -eq 17 -o $channel -eq 25 -o $channel -eq 33 -o $channel -eq 41 -o $channel -eq 49 -o $channel -eq 57 -o $channel -eq 65 -o $channel -eq 73 -o $channel -eq 81 -o $channel -eq 89 -o $channel -eq 97 ]
				then
					return 132
				elif [ $channel -eq 105 -o $channel -eq 113 -o $channel -eq 121 -o $channel -eq 129 -o $channel -eq 137 -o $channel -eq 145 -o $channel -eq 153 -o $channel -eq 161 -o $channel -eq 169 -o $channel -eq 177 -o $channel -eq 185 -o $channel -eq 193 ]
				then
					return 132
				elif [ $channel -eq 201 -o $channel -eq 209 -o $channel -eq 217 -o $channel -eq 225 ]
				then
					return 132
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
			*HT80)
				if [ $channel -eq 1 -o $channel -eq 17 -o $channel -eq 33 -o $channel -eq 49 -o $channel -eq 65 -o $channel -eq 81 -o $channel -eq 97 -o $channel -eq 113 -o $channel -eq 129 -o $channel -eq 145 -o $channel -eq 161 -o $channel -eq 177 -o $channel -eq 193 -o $channel -eq 209 ]
				then
					return 133
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
			*HT160)
				if [ $channel -eq 1 -o $channel -eq 33 -o $channel -eq 65 -o $channel -eq 97 -o $channel -eq 129 -o $channel -eq 161 -o $channel -eq 193 ]
				then
					return 134
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
			*HT80_80) return 135;;
			*)
				if [ $channel -ge 1 -a $channel -le 233 ]
				then
					return 131
				else
					echo "Invalid HTMODE to the configured channel" > /dev/console
					return 0
				fi
			;;
		esac
	fi
}
