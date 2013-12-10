#!/bin/sh

sudo killall tlldpd
sudo ip netns exec host1 ../tiny-lldpd/tlldpd -d
sudo ip netns exec host2 ../tiny-lldpd/tlldpd -d
sudo ip netns exec host3 ../tiny-lldpd/tlldpd -d
sudo ip netns exec host4 ../tiny-lldpd/tlldpd -d
