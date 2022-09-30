#!/bin/sh

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

truncate --no-create --size 0 /tmp/tidy-uid.log

log_echo() {
	MSG=$1
	echo "${MSG}" | tee -a /tmp/tidy-uid.log
}

collect_file() {
	SSH_COMMAND_L=$1
	OLD_UID_L=$2
	OLD_GID_L=$3

	${SSH_COMMAND_L} "find / -uid ${OLD_UID_L} > /tmp/uid-files.${OLD_UID_L} \
        2>/dev/null" </dev/null

	${SSH_COMMAND_L} "find / -gid ${OLD_GID_L} > /tmp/gid-files.${OLD_GID_L} \
        2>/dev/null" </dev/null

	${SSH_COMMAND_L} "find / -uid ${OLD_UID_L} -perm -4000 > /tmp/suid-files.${OLD_UID_L} \
        2>/dev/null" </dev/null

	${SSH_COMMAND_L} "find / -gid ${OLD_GID_L} -perm -2000 > /tmp/sgid-files.${OLD_GID_L} \
        2>/dev/null" </dev/null

	${SSH_COMMAND_L} "find / -uid ${OLD_UID_L} -perm -1000 > /tmp/soid-files.${OLD_UID_L} \
        2>/dev/null" </dev/null
}

# Gather all /etc/passwd for deciding base uid:gid
PASSWD_FILES=""
while read -r LINE; do
	HOST=$(echo "${LINE}" | cut -d" " -f1)
	IP=$(echo "${HOST}" | cut -d"@" -f2)
	PEM=$(echo "${LINE}" | cut -d" " -f2)
	SSH_COMMAND="ssh ${SSH_OPTS} -i ${PEM} ${HOST}"

	log_echo "[+] ${IP}: Extracting /etc/passwd"
	PASSWD_FILES="${PASSWD_FILES}
$(${SSH_COMMAND} "cat /etc/passwd | \
    grep -P 'sh[a-zA-Z0-9]*$' | grep -ve 'shutdown$'" </dev/null)"
	log_echo ""
done <./ip.txt
PASSWD_FILES=$(echo "${PASSWD_FILES}" | grep -ve '^$')

# Deciding base uid:gid by majority
log_echo "[+] Determining base UID:GID"
log_echo "    [+] Getting unique usernames"
USERNAMES=$(printf "%s" "${PASSWD_FILES}" | cut -d":" -f1 | sort | uniq |
	grep -ve "^root")

log_echo "    [+] Counting username:uid:gid occurrences"
STATS=$(printf "%s" "${PASSWD_FILES}" | cut -d":" -f1,3,4 | sort |
	grep -ve "^root" | uniq -c)

log_echo "    [+] Getting the majority"
BASE=""
while read -r LINE; do
	TEMP=$(echo "${STATS}" | grep -P "\s+\d\s${LINE}:" | sort -rnk 1 |
		head -1 | awk '{print $NF}')
	log_echo "        ${TEMP}"
	BASE="${BASE}
${TEMP}"
done <<EOFABC
${USERNAMES}
EOFABC

BASE=$(echo "${BASE}" | grep -ve '^$')

# Tidying overlapping base UID:GID
# Getting overlapping entry
log_echo ""
log_echo "[+] Tidying overlapping base UID:GID"
DUP=$(echo "${BASE}" | cut -d ":" -f 2,3 | sort | uniq -c | sort -rnk 1 |
	grep -vPe "^\s+1\s" | awk '{print $NF}')

DUP_ENTRY=""

while read -r LINE; do
	[ -z "${LINE}" ] && break
	N=$(echo "${BASE}" | grep "${LINE}")
	COUNT=$(echo "${N}" | wc -l)
	COUNT=$((COUNT - 1))
	N=$(echo "${N}" | tail -${COUNT})
	DUP_ENTRY="${DUP_ENTRY}
${N}"
done <<EOFDUP
${DUP}
EOFDUP

DUP_ENTRY=$(echo "${DUP_ENTRY}" | grep -ve '^$')

NUM=1000
while read -r LINE; do
	[ -z "${LINE}" ] && break
	IDS=$(echo "${LINE}" | cut -d ":" -f 2,3)
	USERNAME=$(echo "${LINE}" | cut -d ":" -f1)
	while echo "${BASE}" | grep "${NUM}:${NUM}" >/dev/null; do
		NUM=$((NUM + 1))
	done
	BASE=$(echo "${BASE}" | sed "s/${USERNAME}:${IDS}/${USERNAME}:${NUM}:${NUM}/")
done <<EOFDUPENTRY
${DUP_ENTRY}
EOFDUPENTRY

log_echo ""
log_echo "[+] Final base UID:GID"
log_echo "${BASE}"
log_echo ""

# Tidying UID:GID
while read -r LINE; do
	HOST=$(echo "${LINE}" | cut -d" " -f1)
	IP=$(echo "${HOST}" | cut -d"@" -f2)
	PEM=$(echo "${LINE}" | cut -d" " -f2)
	CONTROL_PATH="$HOME/.ssh/control-${IP}"
	ERR_LOG="/tmp/ssh.${HOST}"
	SSH_COMMAND="ssh -T -o ControlPath=${CONTROL_PATH} ${SSH_OPTS} -i ${PEM} ${HOST}"

	# Start master ssh process
	log_echo ""
	log_echo "[+] IP: ${IP}"
	log_echo "[+] Starting master ssh process"
	log_echo "[+] Error Log: ${ERR_LOG}"
	($SSH_COMMAND -M -f tail -f /dev/null) 2>"${ERR_LOG}"
	log_echo "[+] Master ssh process successfully started"
	log_echo ""

	log_echo "[+] Collecting files"
	while read -r ENTRY; do
		USERNAME=$(echo "${ENTRY}" | cut -d":" -f1)
		BASE_UID=$(echo "${ENTRY}" | cut -d":" -f2)
		OLD_UID=$(${SSH_COMMAND} "id -u ${USERNAME}" </dev/null 2>&0)
		OLD_GID=$(${SSH_COMMAND} "id -g ${USERNAME}" </dev/null 2>&0)
		if [ "${OLD_UID}" != "${BASE_UID}" ] && [ "${OLD_UID}" != "" ]; then
			collect_file "${SSH_COMMAND}" "${OLD_UID}" "${OLD_GID}"
		fi
	done <<EOFBASE1
    ${BASE}
EOFBASE1

	while read -r ENTRY; do
		USERNAME=$(echo "${ENTRY}" | cut -d":" -f1)
		BASE_UID=$(echo "${ENTRY}" | cut -d":" -f2)
		BASE_GID=$(echo "${ENTRY}" | cut -d":" -f3)
		OLD_UID=$(${SSH_COMMAND} "id -u ${USERNAME}" </dev/null 2>&0)
		OLD_GID=$(${SSH_COMMAND} "id -g ${USERNAME}" </dev/null 2>&0)
		if [ "${OLD_UID}" != "${BASE_UID}" ] && [ "${OLD_UID}" != "" ]; then
			log_echo "[+] Changing ${USERNAME} UID and GID from ${OLD_UID} to ${BASE_UID}"
			${SSH_COMMAND} "sudo groupmod -og ${BASE_GID} \
                ${USERNAME}" </dev/null

			${SSH_COMMAND} "sudo usermod -ou ${BASE_UID} -g ${BASE_GID} \
                ${USERNAME}" </dev/null

			log_echo "[+] Changing ${USERNAME} files owner outside of \$HOME directory"
			${SSH_COMMAND} "cat /tmp/uid-files.${OLD_UID} | \
                sudo xargs -I{} chown -h ${BASE_UID} {}" </dev/null
			${SSH_COMMAND} "rm /tmp/uid-files.${OLD_UID}" </dev/null

			${SSH_COMMAND} "cat /tmp/gid-files.${OLD_GID} | \
                sudo xargs -I{} chgrp -h ${BASE_UID} {}" </dev/null
			${SSH_COMMAND} "rm /tmp/gid-files.${OLD_UID}" </dev/null

			log_echo "[+] Setting sticky bit back"
			${SSH_COMMAND} "cat /tmp/suid-files.${OLD_UID} | \
                sudo xargs -I{} chmod u+s {}" </dev/null
			${SSH_COMMAND} "rm /tmp/suid-files.${OLD_UID}" </dev/null

			${SSH_COMMAND} "cat /tmp/sgid-files.${OLD_GID} | \
                sudo xargs -I{} chmod g+s {}" </dev/null
			${SSH_COMMAND} "rm /tmp/sgid-files.${OLD_UID}" </dev/null

			${SSH_COMMAND} "cat /tmp/soid-files.${OLD_UID} | \
                sudo xargs -I{} chmod o+s {}" </dev/null
			${SSH_COMMAND} "rm /tmp/soid-files.${OLD_UID}" </dev/null

			log_echo ""
		fi
	done <<EOFCBA
    ${BASE}
EOFCBA

	log_echo ""
	log_echo "[+] Stopping master ssh process"
	log_echo "[+] $(${SSH_COMMAND} -O exit 2>&1)"
	log_echo "[+] Master ssh process successfully stopped"
	log_echo ""
done <./ip.txt
