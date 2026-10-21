// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Motorcomm YT921x Switch 802.1Q VLAN Tagging Driver
 *
 * Adapted for Qualcomm IPQ5332 PPE hardware acceleration:
 * Uses standard IEEE 802.1Q (0x8100) VLAN tags to identify ports.
 *
 * TX: inserts 4-byte 802.1Q tag with VID corresponding to port index.
 * RX: extracts VID, identifies source port, strips 802.1Q tag.
 */

#include <linux/etherdevice.h>
#include <linux/if_vlan.h>
#include <linux/skbuff.h>
#include <net/dsa.h>

#include "dsa_priv.h"
#include "yt921x.h"

#define YT921X_TAG_NAME	"yt921x"

static struct sk_buff *
yt921x_tag_xmit(struct sk_buff *skb, struct net_device *netdev)
{
	struct dsa_port *dp = dsa_slave_to_port(netdev);
	u16 vid = yt921x_port_to_vid(dp->index);

	return vlan_insert_tag(skb, htons(ETH_P_8021Q), vid);
}

static struct sk_buff *
yt921x_tag_rcv(struct sk_buff *skb, struct net_device *netdev,
	       struct packet_type *pt)
{
	u16 *tag;
	u16 vlan_tci, vid;
	int port;

	if (unlikely(!pskb_may_pull(skb, VLAN_HLEN)))
		return NULL;

	/*
	 * 'skb->data' points into the middle of the 802.1Q tag information:
	 *
	 * ~ MAC src   | 0x81 | 0x00 | 0xyy | 0xzz | ether type
	 *                           ^
	 *                        ->data
	 *
	 * tag[0] (skb->data - 2) is the TPID (0x8100).
	 * tag[1] (skb->data) is the TCI (PCP + DEI + VID).
	 */
	tag = (u16 *)(skb->data - 2);

	if (unlikely(tag[0] != htons(ETH_P_8021Q))) {
		if (is_link_local_ether_addr(eth_hdr(skb)->h_dest))
			return NULL;

		dev_warn_ratelimited(&netdev->dev,
				     "Unexpected packet without 802.1Q tag (proto 0x%04x)\n",
				     ntohs(tag[0]));
		return NULL;
	}

	vlan_tci = ntohs(tag[1]);
	vid = vlan_tci & VLAN_VID_MASK;
	port = yt921x_vid_to_port(vid);

	skb->dev = dsa_master_find_slave(netdev, 0, port);
	if (unlikely(!skb->dev)) {
		dev_warn_ratelimited(&netdev->dev,
				     "Couldn't decode slave for VID %u (port %d)\n",
				     vid, port);
		return NULL;
	}

	skb->priority = (vlan_tci & VLAN_PRIO_MASK) >> VLAN_PRIO_SHIFT;

	/*
	 * Canonical DSA 802.1Q strip pattern (as in net/dsa/tag_lan9303.c):
	 * Remove the 4-byte 802.1Q tag between the MAC addresses and
	 * the real EtherType by pulling VLAN_HLEN and shifting the
	 * 12-byte MAC header forward over the tag.
	 */
	skb_pull_rcsum(skb, VLAN_HLEN);
	memmove(skb->data - ETH_HLEN, skb->data - (ETH_HLEN + VLAN_HLEN),
		2 * ETH_ALEN);

	return skb;
}

static const struct dsa_device_ops yt921x_netdev_ops = {
	.name	= YT921X_TAG_NAME,
	.proto	= DSA_TAG_PROTO_YT921X,
	.xmit	= yt921x_tag_xmit,
	.rcv	= yt921x_tag_rcv,
	.overhead = VLAN_HLEN,
};

MODULE_DESCRIPTION("DSA 802.1Q tag driver for Motorcomm YT921x switches");
MODULE_LICENSE("GPL");
MODULE_ALIAS_DSA_TAG_DRIVER(DSA_TAG_PROTO_YT921X);

module_dsa_tag_driver(yt921x_netdev_ops);
