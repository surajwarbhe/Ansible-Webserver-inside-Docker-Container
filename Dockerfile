FROM centos:latest
RUN yum install openssh-server -y
RUN yum install openssh-server -y
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN ssh-keygen -A
RUN echo "root:centos" | chpasswd
CMD ["/usr/sbin/sshd", "-D"]
