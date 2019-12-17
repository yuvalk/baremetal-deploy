yum install -y vim
yum install -y git
yum install -y ipmitool
yum install -y libvirt qemu-kvm mkisofs

dnf install -y go
dnf groupinstall "Development Tools"
# the whatever commands to install cri-o (runc, buildah, etc.)
