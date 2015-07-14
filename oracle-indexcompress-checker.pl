#!/usr/bin/perl
use strict;
use warnings;
use DBD::Oracle;
use Data::Dumper;
use Getopt::Long;
use Term::ANSIColor qw( :constants );
$Term::ANSIColor::AUTORESET = 1;

my ($user,$pw,$sid);
my $host='localhost';
my $port='1521';
my $last_ana_day=7;
my $tblnm="";
my $line="----------------------------------------------------------------------------------------------------";
GetOptions('user=s' =>\$user,'password=s'=> \$pw,'host=s'=>\$host,
		'sid=s'=>\$sid,'port=s'=>\$port,'lastday=s'=>\$last_ana_day,'table=s'=>\$tblnm);

if(!$user || !$pw | !$sid)
{
	print "[OPTIONS]\n--user USERNAME[default none]\n--password PASSWORD[default none]\n";
        print "--host HOSTNAME[default localhost]\n--sid SID[default none]\n--table TABLENAME[default none]\n";
        print "--port LISTENER PORT[default 1521]\n--lastday THE BEFORE DAY LAST ANALYSED[default 7]\n";
	exit;
}

my $ORADBH=Ora_Connect_Db($host,$port,$sid,$user,$pw);

#get column list sql
my $colsql="select utc.TABLE_NAME,utc.COLUMN_NAME,utc.NUM_DISTINCT,ut.NUM_ROWS,ut.LAST_ANALYZED
		from user_tab_columns utc join user_tables ut 
		on ut.table_name=utc.table_name where ut.LAST_ANALYZED > sysdate - $last_ana_day and ut.NUM_ROWS > 100000";
$colsql=$colsql." and ut.table_name='$tblnm'" if ($tblnm);
#get table list sql
my $inxsql="select uic.INDEX_NAME,uic.TABLE_NAME,uic.COLUMN_NAME,uic.COLUMN_POSITION,ui.LAST_ANALYZED,DISTINCT_KEYS
		from user_ind_columns uic join user_indexes ui 
		on uic.INDEX_NAME=ui.INDEX_NAME where 
		ui.COMPRESSION <> 'ENABLED' and ui.LAST_ANALYZED > sysdate - $last_ana_day";
$inxsql=$inxsql." and ui.table_name='$tblnm' " if ($tblnm);
$inxsql=$inxsql." order by 2,1,4";
#print $inxsql."\n";
#put columns num to HASH
my $sth=$ORADBH->prepare($colsql) || die DBI->errstr."$!";
$sth->execute || die DBI->errstr."$!";
my ($tn,$cn,$dist,$rows,$col_lists,$tbl_row,$laz,$tbl_analyz);
while(($tn,$cn,$dist,$rows,$laz)= $sth->fetchrow ()) {
	$col_lists->{$tn}->{$cn}=$dist;
	$tbl_row->{$tn}=$rows;
	$tbl_analyz->{$tn}=$laz;
}
$sth->finish;
#print Dumper $col_lists;print Dumper $tbl_row;print Dumper $tbl_analyz;
#check index
$sth=$ORADBH->prepare($inxsql) || die DBI->errstr."$!";
$sth->execute || die DBI->errstr."$!";
my ($inm,$itnm,$icnm,$colpos,$analy,$inm_curr,$perc,$idist);
my $cnt=0;
my $compres_col_cnt=0;
format STDOUT =
COLPOSI: @<<<  COLNAME: @<<<<<<<<<<<<<<<<<<<<<< DISTINCT:@>>>>>>>>>>   %:@>>>>>>
        $colpos,       $icnm,                            $col_lists->{$itnm}->{$icnm},$perc
.

while(($inm,$itnm,$icnm,$colpos,$analy,$idist)= $sth->fetchrow ()) {
#print "$inm,$itnm,$icnm,$colpos,$analy,$idist\n";
	next if (!$col_lists->{$itnm});
	next if (!$col_lists->{$itnm}->{$icnm});
	next if (!$tbl_row->{$itnm});
	next if (!$idist);
	if($colpos==1)
	{
		$perc=sprintf("%.2f",($col_lists->{$itnm}->{$icnm}/$tbl_row->{$itnm})*100);
		if($inm_curr)
		{
			Stdout_SQL($inm_curr,$compres_col_cnt);
			$compres_col_cnt=0;
		}
		$inm_curr="";
		if($perc < 50)
		{
			my $recommend=sprintf("%.2f",($idist/$tbl_row->{$itnm})*100);
			print "\n\n\n";
			print "=====================================================================================================\n";
			print "TABLE ANALYZED:";
			print BLUE "$tbl_analyz->{$itnm}";
			print "  INDEX ANALYZED: ";
			print BLUE "$analy\n";
			print "TABLENM: ";
			print GREEN "$itnm\n";
			print "INDEXNM: ";
			print GREEN "$inm\n";
			print "NUMROWS: ";
			print YELLOW "$tbl_row->{$itnm}";
			print "  INDEX_DISTINCT: ";
			print YELLOW "$idist";
			print "  FULL COMPRESS %: ";
			if($recommend < 50)
			{
				print BOLD RED "$recommend";
				#care about system load factor
				if($cnt < 1001){
					print "   BYTES: ";
					print BOLD RED GetBytes($inm);
				}
				print "\n";
			}else{
				print "$recommend\n";
			}
			print "$line\n"; 
			$inm_curr=$inm;
			write(STDOUT);
			$cnt++;
			$compres_col_cnt++;
			next;
		}
	}
	if(!$inm_curr){next;}
	$perc=sprintf("%.2f",($col_lists->{$itnm}->{$icnm}/$tbl_row->{$itnm})*100);
	$compres_col_cnt++ if($perc < 50 && $compres_col_cnt==$colpos-1);
	write(STDOUT);
}
$sth->finish;
if($inm_curr)
{
	Stdout_SQL($inm_curr,$compres_col_cnt);
}
print BOLD RED "\n\nTOTAL RECOMMEND INDEX COUNT: $cnt\n"; 
#oracle connect
sub Ora_Connect_Db {
	my $db = join(';',"dbi:Oracle:host=$_[0]","port=$_[1]","sid=$_[2]");
	my $db_uid_passwd = "$_[3]/$_[4]";
	my $dbh = DBI->connect($db, $db_uid_passwd, "") or die DBI->errstr;
	return $dbh;
}
sub GetBytes{
	my $inm=shift;
	my $sth=$ORADBH->prepare("SELECT SEGMENT_NAME,BYTES FROM USER_SEGMENTS WHERE SEGMENT_NAME='$inm'") || die DBI->errstr."$!";
	$sth->execute || die DBI->errstr."$!";
	my $cnt= $sth->fetchrow ();
	return $cnt;
}
sub Stdout_SQL{
	my $inm_curr=shift;
	my $compres_col_cnt=shift;
	print "REBUILD_SQL: ALTER INDEX $inm_curr rebuild compress $compres_col_cnt;\n";
	print "SIZE_SQL:    SELECT SEGMENT_NAME,BYTES FROM USER_SEGMENTS WHERE SEGMENT_NAME='$inm_curr';\n";
}
