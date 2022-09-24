#!/bin/sh

# TODO: Only use master ssh when changing UID


SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# while read -r LINE; do
#     HOST=$(echo "${LINE}" | cut -d" " -f1)
#     IP=$(echo "${HOST}" | cut -d"@" -f2)
#     PEM=$(echo "${LINE}" | cut -d" " -f2)
#     CONTROL_PATH="$HOME/.ssh/control-${IP}"
#     ERR_LOG="/tmp/ssh.${HOST}"
#     SSH_COMMAND="ssh -T -o ControlPath=${CONTROL_PATH} ${SSH_OPTS} -i ${PEM} ${HOST}" 
#     
#     # Start master ssh process
#     echo "[+] IP: ${IP}"
#     echo "    - Starting master ssh process"
#     echo "    - Error Log: ${ERR_LOG}"
#     ( $SSH_COMMAND -M -f tail -f /dev/null ) 2>"${ERR_LOG}"
#     echo "    - Master ssh process successfully started"
#     echo
# done < ./ip.txt


while read -r LINE; do
    HOST=$(echo "${LINE}" | cut -d" " -f1)
    IP=$(echo "${HOST}" | cut -d"@" -f2)
    PEM=$(echo "${LINE}" | cut -d" " -f2)
    # CONTROL_PATH="$HOME/.ssh/control-${IP}"
    SSH_COMMAND="ssh ${SSH_OPTS} -i ${PEM} ${HOST}" 
    
    echo "[+] ${IP}: Extracting /etc/passwd"
    ${SSH_COMMAND} "cat /etc/passwd;" < /dev/null > "${IP}".passwd
    echo
done < ./ip.txt

PASSWD_FILES=$(cat ./*.passwd)
USERNAMES=$(printf "%s" "${PASSWD_FILES}" | cut -d":" -f1 | sort | uniq | \
    grep -ve "^root")
STATS=$(printf "%s" "${PASSWD_FILES}" | cut -d":" -f1,3,4 | sort | \
    grep -ve "^root" | uniq -c)

BASE=""

while read -r LINE; do
    TEMP=$(echo "${STATS}" | grep -P "\s+\d\s${LINE}:" | sort -rnk 1 | \
        head -1 | awk '{print $NF}')
    BASE="${BASE}
${TEMP}"
done << EOFABC
${USERNAMES}
EOFABC

BASE=$(echo "${BASE}" | grep -ve "^$")

echo "${BASE}" > base.txt


while read -r LINE; do
    HOST=$(echo "${LINE}" | cut -d" " -f1)
    IP=$(echo "${HOST}" | cut -d"@" -f2)
    PEM=$(echo "${LINE}" | cut -d" " -f2)
    CONTROL_PATH="$HOME/.ssh/control-${IP}"
    ERR_LOG="/tmp/ssh.${HOST}"
    SSH_COMMAND="ssh -T -o ControlPath=${CONTROL_PATH} ${SSH_OPTS} -i ${PEM} ${HOST}" 
    
    # Start master ssh process
    echo
    echo "[+] IP: ${IP}"
    echo "[+] Starting master ssh process"
    echo "[+] Error Log: ${ERR_LOG}"
    ( $SSH_COMMAND -M -f tail -f /dev/null ) 2>"${ERR_LOG}"
    echo "    - Master ssh process successfully started"
    echo

    while read -r ENTRY; do
        USERNAME=$(echo "${ENTRY}" | cut -d":" -f1)
        BASE_UID=$(echo "${ENTRY}" | cut -d":" -f2)
        BASE_GID=$(echo "${ENTRY}" | cut -d":" -f3)
        OLD_UID=$(${SSH_COMMAND} "id -u ${USERNAME}" < /dev/null)
        OLD_GID=$(${SSH_COMMAND} "id -g ${USERNAME}" < /dev/null)
        if [ "${OLD_UID}" != "${BASE_UID}" ]; then
            echo "BASE: ${BASE_UID}"
            echo "${USERNAME}:${OLD_UID}"
            echo "    [+] Changing ${USERNAME}"
            # ${SSH_COMMAND} "sudo groupmod -og ${BASE_GID} ${USERNAME}" < /dev/null
            # ${SSH_COMMAND} "sudo usermod -ou ${BASE_UID} ${USERNAME}" < /dev/null
            # ${SSH_COMMAND} "sudo find / -uid ${OLD_UID} \
            #     -exec chown -h ${BASE_UID} {} \; 2>/dev/null" < /dev/null
            # ${SSH_COMMAND} "sudo find / -gid ${OLD_GID} \
            #     -exec chgrp -h ${BASE_GID} {} \; 2>/dev/null" < /dev/null
        fi
    done << EOFCBA
    ${BASE}
EOFCBA

    echo
    echo "[+] Stopping master ssh process"
    echo "[+] $(${SSH_COMMAND} -O exit 2>&1)"
    echo "[+] Master ssh process successfully stopped"
    echo
done < ./ip.txt



# echo
# while read -r LINE; do
#     HOST=$(echo "${LINE}" | cut -d" " -f1)
#     IP=$(echo "${HOST}" | cut -d"@" -f2)
#     PEM=$(echo "${LINE}" | cut -d" " -f2)
#     CONTROL_PATH="$HOME/.ssh/control-${IP}"
#     SSH_COMMAND="ssh -T -o ControlPath=${CONTROL_PATH} ${SSH_OPTS} -i ${PEM} ${HOST}" 
#     
#     echo "[+] IP: ${IP}"
#     echo "    - Terminating master ssh process"
#     echo "    - $(${SSH_COMMAND} -O exit 2>&1)"
#     echo "    - Master ssh process successfully terminated"
#     echo
# done < ./ip.txt


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
