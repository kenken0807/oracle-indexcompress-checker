# oracle-indexcompress-checker
It checks indexes to recommend that it be compressed
and this is for oracle database

#install
<pre>
cpanm install DBD::Oracle
cpanm install Term::ANSIColor
</pre>

#option
<pre>
--user USERNAME[default none]
--password PASSWORD[default none]
--host HOSTNAME[default localhost]
--sid SID[default none]
--table TABLENAME[default none] if you want to check only one table
--port LISTENER PORT[default 1521]
--lastday  LAST ANALYSED DAY WITH TABLES AND INDEXES[default 7]
　　　　　 To target only tables and indexes that has acquired the statistics later than the number of days
</pre>

#execute
<pre>
perl oracle-indexcompress-checker.pl --user orauser --password orauser --sid orcl --lastday 1
</pre>

#result
<pre>
=====================================================================================================
TABLE ANALYZED:2015/07/14 12:25:40  INDEX ANALYZED: 2015/07/14 12:25:41
TABLENM: TESTTABLE
INDEXNM: IDX_TESTKEY
NUMROWS: 600000  INDEX_DISTINCT: 2000  FULL COMPRESS %: 0.33   BYTES: 13631488
----------------------------------------------------------------------------------------------------
COLPOSI: 1     COLNAME: TESTKEY                 DISTINCT:       2000   %:   0.33
REBUILD_SQL: ALTER INDEX IDX_TESTKEY rebuild compress 1;
SIZE_SQL:    SELECT SEGMENT_NAME,BYTES FROM USER_SEGMENTS WHERE SEGMENT_NAME='IDX_TESTKEY';
</pre>

<pre>
TABLE ANALYZED: 　LAST ANALYSED DAY OF TABLE
INDEX ANALYZED: 　LAST ANALYSED DAY OF INDEX
TABLENM:　　　　　TABLENAME
INDEXNM:　　　　　INDEXNAME
NUMROWS:　　　　　NUMROWS OF TABLE
INDEX_DISTINCT:　 Cardinality of the index
FULL COMPRESS %:　(INDEX_DISTINCT/NUMROWS)*100・・This value is to be recommended that you compress in the case of less than 50%
BYTES:            Size of the index
COLPOSI:          Column order of the index
COLNAME:　　　　　ColumnName
DISTINCT:         Cardinality of the Column　　　　
%: 　　　　　　　 (DISTINCT/NUMROWS)*100
REBUILD_SQL:      SQL statements in order to compress
SIZE_SQL:         SQL statements in order to check size
</pre>
