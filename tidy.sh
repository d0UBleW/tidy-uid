#!/bin/bash

# TODO: POSIX compliant (array, awk=>cut)


SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

while read -r LINE; do
    HOST=$(echo "${LINE}" | cut -d" " -f1)
    IP=$(echo "${HOST}" | cut -d"@" -f2)
    PEM=$(echo "${LINE}" | cut -d" " -f2)
    CONTROL_PATH="$HOME/.ssh/control-${IP}"
    ERR_LOG="/tmp/ssh.${HOST}"
    SSH_COMMAND="ssh -T -o ControlPath=${CONTROL_PATH} ${SSH_OPTS} -i ${PEM} ${HOST}" 
    
    # Start master ssh process
    ( $SSH_COMMAND -M -f tail -f /dev/null ) 2>"${ERR_LOG}"
done < ./ip.txt


while read -r LINE; do
    HOST=$(echo "${LINE}" | cut -d" " -f1)
    IP=$(echo "${HOST}" | cut -d"@" -f2)
    PEM=$(echo "${LINE}" | cut -d" " -f2)
    CONTROL_PATH="$HOME/.ssh/control-${IP}"
    SSH_COMMAND="ssh -T -o ControlPath=${CONTROL_PATH} ${SSH_OPTS} -i ${PEM} ${HOST}" 
    
    ${SSH_COMMAND} "cat /etc/passwd;" < /dev/null > "${IP}".passwd
done < ./ip.txt


while read -r LINE; do
    HOST=$(echo "${LINE}" | cut -d" " -f1)
    IP=$(echo "${HOST}" | cut -d"@" -f2)
    PEM=$(echo "${LINE}" | cut -d" " -f2)
    CONTROL_PATH="$HOME/.ssh/control-${IP}"
    SSH_COMMAND="ssh -T -o ControlPath=${CONTROL_PATH} ${SSH_OPTS} -i ${PEM} ${HOST}" 
    
    ${SSH_COMMAND} -O exit
done < ./ip.txt

PASSWD_FILES=$(cat ./*.passwd)

USERNAMES=$(printf "%s" "${PASSWD_FILES}" | cut -d":" -f1 | sort | uniq | \
    grep -ve "^root")

STATS=$(printf "%s" "${PASSWD_FILES}" | cut -d":" -f1,3,4 | sort | \
    grep -ve "^root" | uniq -c)

echo "${USERNAMES}"
echo "${STATS}"



# BASE=($(ssh ${SSH_OPTS} -i ${PEM[0]} ${HOST[0]} \
#     "sudo cat /etc/passwd | tail -4" 2>/dev/null \
#     | awk -F ":" '{print $1 ":" $3 ":" $4 }'))
#
# unset HOST[0]
# unset PEM[0]
#
# echo ${BASE[@]}
#
# for KEY in ${!BASE[@]}
# do
#     USERNAME=$(echo ${BASE[${KEY}]} | cut -d":" -f1)
#     BASE_UID=$(echo ${BASE[${KEY}]} | cut -d":" -f2)
#     BASE_GID=$(echo ${BASE[${KEY}]} | cut -d":" -f3)
#
#     for i in ${!HOST[@]}
#     do
#         REMOTE_OLD_UID=$(ssh ${SSH_OPTS} -i ${PEM[$i]} ${HOST[$i]} \
#             "sudo id -u ${USERNAME}")
#
#         ssh ${SSH_OPTS} -i ${PEM[$i]} ${HOST[$i]} \
#             "sudo usermod -u ${BASE_UID} ${USERNAME}; \
#             sudo find /tmp -uid ${REMOTE_OLD_UID} \
#             -exec chown -h ${BASE_UID} {} \;" < /dev/null
#
#         # TODO: need to reconfigure SUID/SGID after chown
#         # TODO: change GID and create if not exist
#
#     done
# done
