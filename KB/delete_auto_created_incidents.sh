#!/bin/bash

#STOP WCG
/opt/WCG/WCGAdmin stop

SCIP3_DB=/opt/WCG/config/new_scip3.db

#BACKUP new_scip3.db
date=`date +"%Y%m%d%k%M%S"`
cp $SCIP3_DB $SCIP3_DB"_"$date

sqlite3 $SCIP3_DB "delete from certificate_acl where message_short like '%VERIFY DENY:%' or action=2"

#START WCG
/opt/WCG/WCGAdmin start

