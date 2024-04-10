#!/usr/bin/perl -w
use strict;
no warnings 'redefine';
use threads(
  'yield',
  stack_size => 2**20, #1MB
  exit => 'thread_only',
  'stringify'
);
use threads::shared;
use utf8;
use v5.10.0;

push @INC,'.';
$|=1;

our $threads_cnt :shared = 0;

=head1
Waiting the screen input.
Allowed commands:
  e(xit)
  i(nformation)
  s(tart)
  on          show all detail message (including the sent and the received)
  b(rief)     show brief message, only show client requesting port
  off         shutdown non-warning echo
  clear       clear screen
  cls|reset   flush all messages
=cut
print "Manager ready.\n";
while(<STDIN>){
  given($_){
    when(/^e/i){
      last;
    }
    when(/^i/i){
      if(*server::server_call{CODE} ne \&void){
        print "Running threads: ",$threads_cnt,"\n";
      }else{
        warn "No running server\n";
      }
    }
    when(/^s/i){
      start_server();
    }
    when(/^on/i){
      $server::echo_html=1;
    }
    when(/^b/i){
      $server::echo_html=0;
    }
    when(/^off/i){
      $server::echo_html=-1;
    }
    when(/^(cls|reset)/i){
      system "reset";
    }
    when(/^clear/i){
      system "reset";
    }
    default{
      print "Unknown command.\n";
    }
  }
}
print "END\n";

=head1
The main program ends here.
The rest are sub programs.
=cut

=head1
sub to start the server
=cut
sub start_server{
  if(not defined *server::server_call{CODE}){
    require "server.pm";
    
    if(defined *server::server_call{CODE}){
      threads->create(\&server::server_call)->detach();
    }else{
      warn "Load server.pm failed.\n";
    }
  }else{
    warn "Illegal interface.\n";
  }
}