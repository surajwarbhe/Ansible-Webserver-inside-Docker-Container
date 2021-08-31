# Create an Ansible Playbook that will configure Docker and dynamically update the inventory with newly created Docker Container IP

# STEPS:
1. **Enable SSH in the Container using Dockerfile**
2. **Build and Push this image to the Docker Hub**
3. **Ansible Play that will launch and configure the Docker Container and webserver inside it**

## STEP 1: Enable SSH in the Container using Dockerfile

Dockerfile has two types of keyword that helps to configure Image.
1. Build Time: Executes at build time and in the build phase all run time commands are skipped. 
examples are `FROM`, `RUN`, etc.
2. Run Time: Run time commands are `ENTRYPOINT`, `CMD`, etc.

### DockerFile
It is compulsory to give the docker/image file name as `Dockerfile`.
1. To use Base OS from container Image: Dockerfile Keyword: `FROM`
```
FROM centos:latest
```
2. To run OS Specific command: Dockerfile keyword: `RUN`
```
RUN yum install openssh-server -y
```
3. Installing OpenSSH-server
```
RUN yum install openssh-server -y
```
4. Configure SSH Server for password authentication
By Default password authentication is disabled we need to add the below string in the SSHd service configuration file to enable password authentication.
```
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
```
5. Generating Keys
For each of the key types (RSA, DSA, ECDSA, and ED25519) for which host keys do not exist, generate the host keys with the default key file path, an empty passphrase, default bits for the key type, and default comment.
```
RUN ssh-keygen -A
```
6. Changing the Password of the root user
`chpasswd` command is used to change the password although `passwd` command can also do the same. But it changes the password of one user at a time so for multiple users, `chpasswd` is used.
```
# RUN echo "user_name:password" | chpasswd
RUN echo "root:centos" | chpasswd
```
> Default password for this image will be `centos`

7. To start service at runtime
```
CMD ["/usr/sbin/sshd", "-D"]
```
#### Final Image:
```
FROM centos:latest
RUN yum install openssh-server -y
RUN yum install openssh-server -y
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN ssh-keygen -A
RUN echo "root:centos" | chpasswd
CMD ["/usr/sbin/sshd", "-D"]
```

## STEP 2 : Build and push Docker Image to the Docker Hub
Use below command this build your created image
```
docker build -t dockerhub_id/imagename:image_version fileLocation
```
#### To push the image to the Docker registry.
First, we need to give a username and password of the Docker Hub 
For this run the below command-
```
docker login
```
Then run below command to push your created Image
```
docker push dockerhub_id/imagename:image_version
```
> You can use my Docker Image to perform further task.
To Pull my Docker image, use below command-
```
docker pull surajwarbhe/ssh_centos:v1
```

## STEP 3 : Ansible Configuration and Playbooks

#### 1. Create an Inventory file

🔶 Create an inventory file with the extension `(.txt)` and leave it blank.
```
vim ip.txt
```

#### 2. Create Ansible Configuration file

🔶 Create a file with the extension `(.cfg)` in the directory `/etc/ansible/`, here I have a configuration file with named `ansible.cfg`
```
vim  /etc/ansible/ansible.cfg
```
🔶 Write below statements in the configuration file.
```
[defaults]
inventory=/root/ip.txt
host_key_checking=false
deprecation_warnings=false
command_warnings=false
```

#### 3. Create and Run Ansible Playbook (To setup Docker)

🔶 Create an Ansible playbook with an extension `(.yml)` or `(.yaml)`, here I have created a playbook with named `dockertask.yaml`
```
- hosts: localhost
  vars_prompt:
      - name: container_name
        prompt: "Docker Container Name: "
        private: no

  vars:
          - image_name: surajwarbhe/ssh_centos:v1

  tasks:
      - name: Creating Repo for yum
        yum_repository:
            name: docker
            file: docker
            description: Docker Yum Repo
            baseurl: https://download.docker.com/linux/centos/7/x86_64/stable/
            gpgcheck: no

      - name: Installing Python3...
        command: "yum -y install python3"
      - name: Installing Docker Software...
        command: "yum install -y  docker-ce --nobest"

      - name: Starting Docker services...
        service:
            name: "docker"
            state: started
            enabled: yes

      - name: Installing Docker Library...
        command: "pip3 install docker-py"

      - name: pull an image
        docker_image:
            name: "{{ image_name }}"
            source: pull

      - name: "Launching {{ container_name }} Container"
        docker_container:
            name: "{{ container_name }}"
            image: "{{ image_name }}"
            state: started
            interactive: yes
            detach: yes
            tty: yes

      - name: "Container Info"
        docker_container_info:
            name: "{{ container_name }}"
        register: dinfo

      - name: "Printing IP of Docker container..."
        debug:
              msg: "{{ dinfo.container.NetworkSettings.IPAddress}}"

      - name: updating ansible inventory  with new docker info.......
        blockinfile:
            path: "/root/ip.txt"
            block: |
                    [docker]
                    {{ dinfo['container']['NetworkSettings']['IPAddress'] }} ansible_user=root ansible_ssh_pass=centos  ansible_connection=ssh

  handlers:
  - name: docker
    yum:
        name: docker-ce
        state: present
        allow_downgrade: yes
        skip_broken: yes

```

🔶 To run the playbook use the below command-
```
# ansible-playbook <filename>

ansible-playbook dockertask.yaml
```
Initially, it will ask us container name.
I have provided container name as `Arth14`

![root@localhost_~_ansible_tasks 31-08-2021 09_48_59 AM](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/wln2l5z1cnmjmofe684w.png)
Yesss, Our playbook run successfully !
> And we got a `IP address` of newly created Docker Container as `172.17.0.3`

🔶 Let’s Check ip.txt file
Earlier, we had leave ip.txt as empty but now it is updated dynamically with newly created `IP address` Docker container.
![root@localhost_~_ansible_tasks 31-08-2021 09_56_10 AM](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/2mc25d11xbpg675v496e.png)

#### STEP 4 : Check connectivity with Docker Container
We have to check ansible connectivity with newly created Docker Container so that we can perform `SSH` and perform further operations on that. 
Use below command to check connectivity-
```
ansible all -m ping
```
![root@localhost_~_ansible_tasks 31-08-2021 09_55_55 AM](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/cnkqiwvj27vv9dtjqp2z.png)
> If you get `Success` message in a green color and `Ping Pong` at the end, it means everything is OKAY!
  
#### STEP 5 : Configuration of Apache Webserver, Copying the testing Page, and Starting the Apache web service

🔶 Create an Ansible playbook with an extension `(.yml)` or `(.yaml)`, here I have created a playbook with named `webserver.yaml`
```
- hosts: docker
  tasks:
    - name: "Installing Httpd service"
      package:
          name: "httpd"
          state: present

    - name: "Creating html file"
      copy:
          content : "<b><center>HEY! TASK 14.2 Done successfully </center></b>"
          dest: "/var/www/html/index.html"

    - name: "Starting Httpd Service"
      command: "/usr/sbin/httpd"
```

🔶 To run the playbook use the below command-
```
# ansible-playbook <filename>

ansible-playbook webserver.yaml
```
![root@localhost_~_ansible_tasks 31-08-2021 09_56_45 AM](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/0se46wapnpxzo6lxr7oy.png)
Yesss, Our playbook run successfully !


#### STEP 6 : Testing
Use below command to test your configuration OR you can directly type your Docker container's IP address over Browser-
```
# curl <ip_address_of_Docker_container>

curl 172.17.0.3
```
![root@localhost_~_ansible_tasks 31-08-2021 10_15_50 AM](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/u9u2hlg7qhrrd9os4z1a.png)
![567 (2)](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/eejaohv6pr6c6gcdq7wc.png) 

**YAY! The Web-Server is configured successfully inside Container.** 💥💥
