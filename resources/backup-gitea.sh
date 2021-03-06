#!/bin/sh
BIN="$( cd "$( dirname "$0" )" && pwd )"   # https://stackoverflow.com/a/20434740

# Inject through pod environment variables
#echo -e "\n\n+ Load environment variables..."
#source $BIN/setenv   # https://stackoverflow.com/a/13360474
#cat $BIN/setenv      # for logging

# Find Gitea Pod
#POD=git-gitea-5cfdbb68cf-xwm7c
POD=$(kubectl get pods --no-headers=true -o custom-columns=:.metadata.name | grep -- $GITEA_DEPLOY)
if [ -z "$POD" ]; then
	echo -e '\n\n+ ERROR :: There is no gitea pod.'
	kubectl get pods
	echo 'ERROR' > $S3_TRIGGER
	exit 1
fi

# 
GITEA=/app/gitea
DUMP_PETTERN=$GITEA/gitea-dump-*.zip

echo -e "\n\n+ Dump gitea data..."
time kubectl exec -i $POD -- bash -c "cd $GITEA && ./gitea dump "
kubectl exec -i $POD -- bash -c "ls -t $DUMP_PETTERN | head -n1" > latest
tr -d '\r' <latest >latest.tmp && mv latest.tmp latest    # https://unix.stackexchange.com/a/259991

# Logging Backup Status
kubectl exec -i $POD -- bash -c "ls -al $GITEA"
cat latest

if [ -z latest ]; then
	echo 'ERROR :: There is no dump files.'
	kubectl exec -i $POD -- bash -c "ls -al $GITEA"
	exit 1
fi

echo -e "\n\n+ Copy dump files..."
kubectl cp $POD:$(cat latest) $BACKUP_DIR
kubectl exec -i $POD -- bash -c "rm -f $(cat latest)"
ls -l $BACKUP_DIR

# Trigger s3 upload
echo 'START' > $S3_TRIGGER
