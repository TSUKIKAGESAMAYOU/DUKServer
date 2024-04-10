#!/usr/bin/perl
use v5.10.0;

BEGIN{
  sub uri_unescape{
    shift;
  }
  eval "use URI::Escape";
}
$content_type=<>;
$/=undef;
my $file=<>;
given($content_type){
  when("application/x-www-form-urlencoded"){
    $file = uri_unescape($file);
  }
  default{
    
  }
}
print "text/html; charset=utf-8\n";
print "<html>",($file."<br/>") x 20,"</html>";