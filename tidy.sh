#!/bin/bash

# TODO: POSIX compliant (array, awk=>cut)

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

IP=($(cat ./ip.txt | cut -d" " -f1))
PEM=($(cat ./ip.txt | cut -d" " -f2))

BASE=($(ssh ${SSH_OPTS} -i ${PEM[0]} vagrant@${IP[0]} \
    "sudo cat /etc/passwd | tail -4" 2>/dev/null \
    | awk -F ":" '{print $1 ":" $3 ":" $4 }'))

unset IP[0]
unset PEM[0]

echo ${BASE[@]}

for KEY in ${!BASE[@]}
do
    USERNAME=$(echo ${BASE[${KEY}]} | cut -d":" -f1)
    BASE_UID=$(echo ${BASE[${KEY}]} | cut -d":" -f2)
    BASE_GID=$(echo ${BASE[${KEY}]} | cut -d":" -f3)

    for i in ${!IP[@]}
    do
        REMOTE_OLD_UID=$(ssh ${SSH_OPTS} -i ${PEM[$i]} vagrant@${IP[$i]} \
            "sudo id -u ${USERNAME}")

        ssh ${SSH_OPTS} -i ${PEM[$i]} vagrant@${IP[$i]} \
            "sudo usermod -u ${BASE_UID} ${USERNAME}; \
            sudo find /tmp -uid ${REMOTE_OLD_UID} \
            -exec chown -h ${BASE_UID} {} \;" < /dev/null

        # TODO: need to reconfigure SUID/SGID after chown
        # TODO: change GID and create if not exist

    done
done
