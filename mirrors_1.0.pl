#!/usr/bin/perl
#by: Michael Hollifield
#emailto: michael.hollifield@insightbb.com
#this is by no means the best code but it works well. 

#usage: 
#this is used to return mirrors of files you might want to download. gives the url and locations

#perl mirrors.pl -searchtype=(see below) -searchfile=abcdefg.csd -requesturl=http://abc.asd.sds
#	where
#		-searchtype=begins, contains, equals or ends
#		-searchname=any name of a file. not images or such .. see www.filemirrors.com for details
#		-requesturl=this is used by itself to parse a url for its tags
#		-returnedfield=(see below).for returned data

#the first field returned is the index for the entry. so you will see multiple 1's or so which mean all the fields returned are related.

my $VERSION=1.0;

# @ARGV is the command listing passed in
# $#ARGV is the number of arguments passed in minus 1

use strict;
use Getopt::Long;	#used for command line parsing
use LWP::Simple;	#used for web retrieval

use diagnostics;	#verbose info

diagnostics::enable;	#turn on verbose logging

package main;		#package name


#declarations of globals
my($NAME)="mirrors.pl";		#variable for the name of this file
my($HOST)=`/bin/hostname`;	#variable to hold the hostname
chomp($HOST);


my($searchname)='';		#variable for holding the file search request
my($searchtype)='';		#variable to contain the search type
my($requesturl)='';		#variable for a requested url to parse

				#begins
				#contains
				#equals
				#ends

				
#Date variables
my(@date);
my($Month);
my($Date);
my($Time);
my($Year);


#filemirrors variables for parsing
my($startlooking)="Search Results";	#this is used to mark the start of the searching for data
my(%returnedsearchdata);		#this is a hash to store the data into
my($filesearching)=0;			#used to designate if we are doing a filemirrors seach
my($insideregion)=0;			#used to track if we have found our start mark
my($startrow)=1;			#starting row for our data
my($rowcounter)=0;			#row counter
my($datacounter)=0;			#used to count the data in a row

my($newrowdata)=0;
my($newrow)=0;
my($href)=0;				#tracker if we are in a href line

my($tagend)=0;				#for tracking if its the beginning of a tag or a end
my(@returnedfield);			#returned fields requested.
	#returned fields are:
			#href
			#location
			#filesize
			#date
			#filename

my($verbose)=0;				#verbose setting. 1 = output debug info

{
	package MyParser;
	use base 'HTML::Parser';

	sub start
	{
		#used for a start of a tag
		my($self, $tagname,$attr,$attrseq,$origtext)=@_;
		my($key);
		my($attribute);

		if($filesearching==0 || $verbose ne 0){print "Name of Tag: $tagname\n";}

		foreach $key (keys %$attr)
		{
			if($filesearching==0 || $verbose ne 0){print "\t\t$key:\t$attr->{$key}\n";}
		}
			
		foreach $attribute (@$attrseq)
		{
			chomp($attribute);
			if($filesearching==0 || $verbose ne 0){print "\t\tAttrib:\t$attribute\n";}
		}
		if($filesearching==0 || $verbose ne 0){print "\tOriginal Text: $origtext\n";}
		$tagend=0;

		if ($filesearching==1)
		{
			#we are searching the filemirror. look for our tag

			if($insideregion==1)
			{
				
				#we are looking for our start tags for our search
				if($rowcounter ge $startrow)
				{
					#we have passed up our headers already. good to go
					#now looking for the td
					if($tagname eq "td")
					{
							#only care if inside our search region
							#we have a new data row
							#now look for Plain Text
							$newrowdata=1;
							$datacounter++;		#increment the data counter
							#print "Datecounter: $datacounter\n";
							

							#print "\tNew Table Data\n";
							$tagend=0;
					}
					
					if($tagname eq "tr")
					{
						#new row found
						#print "\tInside Row Inside Section\n";
						
						$rowcounter++;
						$newrow=1;
						$datacounter=0;

						#print "\tNew Table Row Row Count: $rowcounter\n";
						$tagend=0;
						
					}
					
					if($tagname eq "a")
					{
						#we need to store the href here
						if($datacounter ge 1)
						{
							$returnedsearchdata{$rowcounter}{'href'}=$attr->{href};
							if($verbose ne 0){print "\thref: ".$returnedsearchdata{$rowcounter}{'href'}."\n";}
							$href=1;
						}
						$tagend=0;
					}
					
					
				}
				else
				{
					#have not passed up headers yet. wait for enough
					if($tagname eq "tr")
					{
							#only care if inside our search region
							#new row
							$rowcounter++;
							$newrow=1;
							$datacounter=0;	#reset the data counter
							$tagend=0;
							
					}
					
					if($tagname eq "td")
					{
						#new table data entry
						$newrowdata=1;
						$datacounter++;		#increment the data counter
						#print "Datecounter: $datacounter\n";
						$tagend=0;

					}
				}
			}
		}
		
	}

	sub end
	{
		my($self,$tagname,$origtext)=@_;
		if($filesearching==0 || $verbose ne 0){print "Tag End: $tagname\n";}
		if($filesearching==0 || $verbose ne 0){print "\tOriginal Text: $origtext\n";}
		
		if($tagname eq "tr")
		{
			#end of our row
			$newrow=0;
		}
		
		if($tagname eq "td")
		{
			$newrowdata=0;
			#$datacounter=0;
		}
		$tagend=1;
	}

	sub text
	{
		my($self,$origtext,$is_cdata)=@_;
		chomp($origtext);
		$origtext=~s/^\s+//;
		$origtext=~s/\s+$//;
		if($filesearching==0 || $verbose ne 0)
		{
			if($origtext ne ''){print "Plain Text: $origtext\n";}
		}
		
		if($filesearching ==1 && $tagend eq 0)
		{
			#we are looking for our start point
			if($origtext=~/$startlooking/)
			{
				#print "\tInside Region\n";
				$insideregion=1;
			}
		
			#print "Datecounter: $datacounter\n";	
			if($datacounter eq 1)
			{
				$returnedsearchdata{$rowcounter}{'location'}=$origtext;
				if($verbose ne 0){print "\tLocation: ".$returnedsearchdata{$rowcounter}{'location'}."\n";}
			}
			elsif($datacounter eq 3)
			{
				$returnedsearchdata{$rowcounter}{'filesize'}=$origtext;
				if($verbose ne 0){print "\tFilesize: ".$returnedsearchdata{$rowcounter}{'filesize'}."\n";}
			}
			elsif($datacounter eq 2 && $href==1)
			{
				#we are in a plain text option for a hfref
				$returnedsearchdata{$rowcounter}{'filename'}=$origtext;
				if($verbose ne 0){print "\tFilename: ".$returnedsearchdata{$rowcounter}{'filename'}."\n";}
				$href=0;
				
			}
			elsif($datacounter eq 4)
			{
				$returnedsearchdata{$rowcounter}{'date'}=$origtext;
				if($verbose ne 0){print "\tDate: ".$returnedsearchdata{$rowcounter}{'date'}."\n";}
			}
		
		}
		
	}

	sub declaration
	{
		my($self,$declaration)=@_;
		chomp($declaration);
		if($filesearching==0 || $verbose ne 0)
		{
			if($declaration ne ''){print "Declaration: $declaration\n";}
		}

	}
	sub comment
	{
		my($self,$comment)=@_;
		chomp($comment);
		if($filesearching==0 || $verbose ne 0)
		{
			if($comment ne ''){print "Comment: $comment\n";}
		}
	}
}

sub main()
{
	#main routine
	
	GetOptions('filename=s'=>\$searchname,'f=s'=>\$searchname,'searchtype=s'=>\$searchtype,'s=s'=>\$searchtype,'requesturl=s'=>\$requesturl,'u=s'=>\$requesturl,'verbose=s'=>\$verbose,'v=s'=>\$verbose,'returnfield=s'=>\@returnedfield,'r=s'=>\@returnedfield);
	#valid searchtypes are defined above.

	
	if($searchname ne '' && $searchtype ne '' && $requesturl eq '')
	{
		$filesearching=1;
		
		my($requestinfo)='';
		$requestinfo=get("http://www.filemirrors.com/search.src?type=begins&file=$searchname");
		my($parser)=MyParser->new();
		$parser->parse($requestinfo);
		
		#we need to parse the data now.
		foreach my $key ( keys %returnedsearchdata ) 
		{
			my(%tmphash)=%{$returnedsearchdata{$key}};
			
			foreach my $retfield (@returnedfield)
			{
				if($tmphash{$retfield})
				{
					print "$key\t$retfield:\t$tmphash{$retfield}\n";
				}
			}
		}
		
	}
	elsif($requesturl ne '')
	{
		#this is just a side benefit of the parsing routines
		
		$filesearching=0;
		#print "$requesturl\n";
		my($requestinfo)='';
		$requestinfo=get($requesturl);
		my($parser)=MyParser->new();
		if($requestinfo ne '')
		{
			$parser->parse($requestinfo);
		}
	}
	else
	{
		print "You must have a valid filename and searchtype\n";
		print "Current Filename: $searchname\n";
		print "Current Search Type: $searchtype\n";
		print "Current url: $requesturl\n";
	}

}

main();
diagnostics::disable;	#turn off verbose diagnostics

1;	#necessary for perl

=head1 NAME

mirrors - This script is used to retrieve a listing of mirrors for files across 
the www. 

=head1 DESCRIPTION

This script will return a listing of files, sizes,dates,urls for a given search name

=head1 README

=head1 PREREQUISITES

This script uses 	Getopt::Long;	#used for command line parsing
			LWP::Simple;	#used for web retrieval

			diagnostics;	#verbose info

=head1 COREQUISITES

=pod OSNAMES

=pod SCRIPT CATEGORIES

CPAN/Scripts
file/mirrors

=cut


