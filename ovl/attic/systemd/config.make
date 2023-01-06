
$(COBJ): I += -I$(XCLUSTER_WORKSPACE)/util-linux-2.31/libmount/src

$(BOBJ): I += -I$(XCLUSTER_WORKSPACE)/util-linux-2.31/libmount/src

$(SYSTEMD) $(SYSTEMCTL) $(SYSRUN): L += -L$(XCLUSTER_WORKSPACE)/util-linux-2.31/.libs
