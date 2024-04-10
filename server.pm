package server;
use threads(
  'yield',
  stack_size => 2**20,
  exit => 'thread_only',
  'stringify'
);
use threads::shared;
use utf8;
use Storable qw(freeze thaw);
use Socket qw(:crlf);
use IO::Socket qw(AF_INET AF_UNIX SOCK_STREAM SHUT_WR SOL_SOCKET SO_REUSEADDR);
use v5.10.0;
use IPC::Open2;

=head1
Constant settting.
=cut
use constant default_port => 80;
use constant max_listen   => 102400;

=head2
  Count the number of running threads.
  Will output wrong number if some threads die unexceptedly.
=cut
our $echo_html    :shared = 0;

=head2
  Load '.ini'
=cut
our %executive    = eval(&loadfile("interpreter.ini")  // "()");
our %exten2type   = eval(&loadfile("content-type.ini") // "()");
our %jmp_page     = eval(&loadfile("jump.ini")         // "()");

=head1
sub server_call:
  Use an eternal cycle to reply the requests.
=cut

sub server_call{
  $| = 1;
  if(my $url = &loadfile('mainpage.ini')){
    $jmp_page{'/'} = $url;
  }else{
    warn "Require but no mainpage set\n";
    $jmp_page{'/'} = "/main.html";
  }
  
  while(1){
    my $server = undef;
    print "asking for ".default_port."...";
    until(defined $server)
    {
      $server = IO::Socket->new(
        Domain    => AF_INET,
        Type      => SOCK_STREAM,
        Proto     => 'tcp',
        LocalHost => '0.0.0.0',#server don't need the host
        LocalPort => default_port,
        Listen    => max_listen,
        Reuse     => 0,
      );
      sleep(1) unless defined $server;
    }
    
    $server->setsockopt(SOL_SOCKET, SO_REUSEADDR, 1);
    print "\b" x 20,"Waiting on " . default_port . "$CRLF";
    
    for(1..max_listen){
      my $client = $server->accept();
      sleep 0.01 until threads->list(threads::running) < max_listen;
      threads->create(\&reply,$client)->detach();
    }
    $server->close();
    $server = undef;
  }
}

=head1
sub reply:
  Use "given..when" structure to match the data received from socket.
  Several subs are used.
=cut
sub reply{
  ++$main::threads_cnt;
  my $client         = shift;
  my $client_address = $client->peerhost();
  my $client_port    = $client->peerport();
  
  my $datarecv;
  {
    local $/ = "$CRLF";
    $datarecv = <$client>;
  }
  
  if(defined $datarecv){
    print "received data from $client_address:$client_port"
                        if $echo_html > -1;
    print ": $datarecv" if $echo_html > 0;
    print "\n"          if $echo_html > -1;
    
    given($datarecv){
      #html
      when(m{
            ^GET                         #deal with get 
            \s
            (?<whole_path>               #get path
              /|                         #'/'
              /?
              (?<path>(?:[^/?]+/)*?)     #/.../.../
              (?<file_name>[^/?]+?)      #x.x
              (?<extension_name>\.[^?.\s]+)?
            )       
            (?:\?(?<args>\S+))?          #get url_args
            \s
            (?<http_ver>HTTP/\S+)        #get HTTP version (usually 1.1/1.0)
            #the rest are unnecessary
          }x){
        #mapping the matching parts
        my ($whole_path,$path,$file_name,$extension_name,$args,$http_ver)
                = ($+{whole_path},$+{path},$+{file_name},$+{extension_name},$+{args},$+{http_ver});
        #default value
        my $header          = $http_ver . " 200 OK",
        my %basic_header    = (
          'Content-Length'     => 0,
        );
        my %append_header   = (
          'Date'               => localtime . ' GMT+8',
        );
        my $accept          = "";
        my $etag            = "";
        while(<$client>){
          print if $echo_html > 0;
          last if /^\s*$/;
          $accept         = $1 if /^Accept: (\S+)/; #get accept to return 406
          $etag           = $1 if /^If-None-Match: (\S+)/;
        }
        print "\n" if $echo_html > 0;
        
        #jump if listed
        if(exists $jmp_page{$whole_path}){
          $header                      = $http_ver . " 302 Found";
          $append_header  {'Location'} = $jmp_page{$whole_path};
        }elsif(not exists $executive{$extension_name}){
          #Etag
          my @stat_server = stat('server.pm');
          my @stat_file   = stat("$path$file_name$extension_name");
          if($#stat_file != -1 and $#stat_server != -1){
            if($etag eq 
                ($append_header{'ETag'} = sprintf "%x%x",$stat_server[9],$stat_file[9])){
              $header = $http_ver." 304 Not Modified";
            }
          }else{
            $header = $http_ver." 404 Not Found";
          }
        }
        
        my $file;
        if($header =~ /200/){
          if(exists $executive{$extension_name}){   #dynamic page running
            $args = $args // '';
            $file = `$executive{$extension_name} $path$file_name$extension_name $args`;
            $file = $file // '';
          }else{
            $file = &loadfile("$path$file_name$extension_name");
          }
          
          if(not defined $file){                    #not found tile and return 404
            $header = $http_ver." 404 Not Found";
          }else{
            $basic_header     {'Content-Length'}      = length $file;
            
            if(exists $exten2type{$extension_name}){
              $basic_header   {'Content-Type'  }      = $exten2type{$extension_name};
            }else{
              $basic_header   {'Content-Type'  }      = 'application/octet-stream';
              
              $append_header  {'Content-Disposition'} = "attachment;filename=$file_name$extension_name";
            }
            
            #match if it's acceptable or return 406
            $basic_header{'Content-Type'} =~ /([^;]+);?/;
            my $type = $1;
            if($accept !~ /$type/ and $accept !~ /\*\/\*/){
              $header = $http_ver." 406 Not Acceptable";
              $file   = "";
              $basic_header {'Content-Length'} = 0;
            }
          }
        }else{
          $file = "";
        }
        
        print $client &build_html(\$header,\%basic_header,\%append_header,\$file);
        print "reply to : $client_address:$client_port\n",
              &build_html(\$header,\%basic_header,\%append_header),"\n"
              if $echo_html > 0;
        break;
      }
      #post
      when(m{
            ^POST                        #deal with post
            \s
            (?<whole_path>               #get path
              /|                         #'/'
              /?
              (?<path>(?:[^/?]+/)*?)     #/.../.../
              (?<file_name>[^/?]+?)      #x.x
              (?<extension_name>\.[^.\s]+)?
            )
            \s
            (?<http_ver>HTTP/\S+)        #get HTTP version (usually 1.1/1.0)
          }x){
        #mapping the matching parts
        my ($whole_path,$path,$file_name,$extension_name,$http_ver)
                = ($+{whole_path},$+{path},$+{file_name},$+{extension_name},$+{http_ver});
        #default value
        my $header          = $http_ver . " 200 OK",
        my %basic_header    = (
          'Content-Length'     => 0,
        );
        my %append_header   = (
          'Date'               => localtime . ' GMT+8',
        );
        
        #the argv to send
        my $args           = "";
        #default encoding is bitstream(download)
        my $content_type   = "application/octet-stream";
        #get accept to return 406
        my $accept         = "";
        {
          my $length = 0;
          while(<$client>){
            print if $echo_html > 0;
            last if /^\s*$/;
            $length        = $1 if /^Content-Length: (\d+)/;
            $content_type  = $1 if /^Content-Type: (\S+)/;
            $accept        = $1 if /^Accept: (\S+)/;
          }
          local $/ = undef;
          read($client,$args,$length);
          print $args,"\n\n" if $echo_html > 0;
        }
        
        #jump if listed
        if(exists $jmp_page{$whole_path}){
          $header                      = $http_ver . " 302 Found";
          $append_header  {'Location'} = $jmp_page{$whole_path};
        }
        
        my $file;
        if($header =~ /200/){
          if(exists $executive{$extension_name}){ #if it's executable (and must be executable)
            my ($read,$write);
            #fork a single process
            if(open2($read,$write,"$executive{$extension_name} $path$file_name$extension_name")){
              print $write $content_type,"\n";
              print $write $args;
              close $write;
              my $content_type = <$read>;
              $content_type = $exten2type{$extension_name}
                    if $content_type =~ /^\s*$/;
              local $/ = undef;
              $file = <$read>;
              
              #get return
              $basic_header     {'Content-Length'}      = length $file;
              $basic_header     {'Content-Type'  }      = $content_type;
              
              #match if it's acceptable or return 406
              $content_type =~ /([^;]+);?/;
              my $type = $1;
              if($accept !~ /$type/ and $accept !~ /\*\/\*/){
                $header = $http_ver." 406 Not Acceptable";
                $file   = "";
                $basic_header {'Content-Length'} = 0;
              }
            }else{
              #404
              $header = $http_ver." 404 Not Found";
            }
            
          }else{
            #not executable
            $header = $http_ver." 405 Method Not Allowed";
          }
        }else{
          $file = "";
        }
        
        print $client &build_html(\$header,\%basic_header,\%append_header,\$file);
        print "reply to : $client_address:$client_port\n",
              &build_html(\$header,\%basic_header,\%append_header)
              if $echo_html > 0;
        break;
      }
      #bad request like (PUT,...)
      default{
        my $header = $http_ver." 501 Not Implemented";
        my %basic_header    = (
          'Content-Length'     => 0,
        );
        my %append_header = (
          'Date'               => localtime . ' GMT+8',
        );
        print $client &build_html(\$header,\%basic_header,\%append_header);
        print "reply to : $client_address:$client_port\n",
              &build_html(\$header,\%basic_header,\%append_header)
              if $echo_html > 0;
        break;
      }
    }
  }else{
    print "received a void package.$CRLF"
          if $echo_html > -1;
  }
  
  $client->shutdown(SHUT_WR);
  --$main::threads_cnt;
}

=head1
sub reply_header:
  The field to build up a http header.
=cut
sub build_html{
  my $http_package  = ${shift @_}.$CRLF.
                      "Server: GenshinImpactServer$CRLF".
                      "Cache-Control: no-cache$CRLF".
                      "Accept-Ranges: bytes$CRLF";
  my %basic_header    = %{shift @_};
  my %append_header   = %{shift @_};
  
  for(keys %append_header){
    $http_package .= $_ . ': ' . $append_header{$_} . $CRLF;
  }
  for(keys %basic_header){
    $http_package .= $_ . ': ' . $basic_header {$_} . $CRLF;
  }
  $http_package   .= $CRLF;
  
  $http_package .= ${shift @_} if $#_>=0;
}

=head1
sub loadfile to read a file and run it.
=cut
sub loadfile{
  local $/ = undef;
  my $file_name = shift;
  if(open my $in,"<$file_name"){
    <$in>
  }else{
    warn "Non-existent file $file_name\n";
    undef
  }
}

return 1;