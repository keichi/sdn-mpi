#!/bin/sh

sudo ip netns exec host1 ../tiny-lldpd/tlldpd -d
sudo ip netns exec host2 ../tiny-lldpd/tlldpd -d
sudo ip netns exec host3 ../tiny-lldpd/tlldpd -d
sudo ip netns exec host4 ../tiny-lldpd/tlldpd -d

trema netns host1

sudo killall tlldpd
