#!/usr/bin/perl
#
# カクヨムの投稿小説を青空文庫形式にしてダウンロードする。
# Copyright (c) 2017 ◆.nITGbUipI
# license GPLv2
#
# Usage.
# ./kakuyomu-dl.pl 目次url > 保存先ファイル名
#
# としてリダイレクトすれば青空文庫形式で保存される。

#
#

use strict;
use warnings;
use LWP::UserAgent;
use HTML::TagParser;
use utf8;
use Encode;
use File::Basename;
use Time::Local 'timelocal';
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Cwd;
use File::Spec;

my $url_prefix = "https://kakuyomu.jp";
my $user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:54.0) Gecko/20100101 Firefox/54.0';
my $separator = "▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n";
my $kaipage = "［＃改ページ］\n";
my ($chklist, $savedir, $split_size, $update, $show_help );
my $last_date;  #前回までの取得日
my $base_path;  #保存先dir
my $charcode = 'UTF-8';

if ($^O =~ m/MSWin32/) {
    $charcode = "cp932";
}

sub get_contents {
    my $address = shift;
    my $http = LWP::UserAgent->new;
    $http->agent($user_agent);
    my $res = $http->get($address);
    my $content = $res->content;
    return $content;
}

# htmlパース
sub html2tree {
    my $item = shift;
    my $tree = HTML::TagParser->new;
    $tree->parse($item);
    return $tree;
    $tree->delete;
}


# 目次作成
sub novel_index {
    my $item = shift;
    my $url_list = [];          # リファレンス初期化
    my $count = 0;
    $item = &html2tree($item);
    my @mokuji = $item->getElementsByClassName('widget-toc-episode');
    foreach my $tmp (@mokuji) {
        my $subtree = $tmp->subTree;
        my $url = $subtree->getElementsByTagName("a")->attributes->{href};
        $url = $url_prefix . $url;
        my $title = $subtree->getElementsByClassName('widget-toc-episode-titleLabel')
                            ->innerText;
        utf8::decode($title);
        my $update = $subtree->getElementsByTagName('time')->attributes->{datetime};
        $update =~ s|(\d{4}-\d{2}-\d{2})T\d.+|$1|;
        $update = &epochtime( $update );
#        print STDERR encode($charcode, "$update:  $title :: $url\n");
        $url_list->[$count] = [$title, $url, $update]; # タイトル、url、公開日
        $count++;
    }

    if ($update) {
        my @reverse = reverse( @$url_list );
        my @up_list = ();
        for (my $i = 0; $reverse[$i]->[2] > $last_date; $i++) {
            push(@up_list, $reverse[$i]);
        }
        @up_list = reverse( @up_list );
        $url_list = \@up_list;
    }
    return $url_list;
}

# 最終更新日
sub last_update {
    my $item = shift;
    $item = &html2tree($item);
    $item = $item->getElementsByClassName('widget-toc-date')
                 ->subTree
                 ->getElementsByTagName('time')->attributes->{datetime};
    return $item;
}

# 作品名、著者名取得
sub header {
    my $item = shift;
    $item = &html2tree( $item );
    my $main_title = $item->getElementsByClassName('widget-works-workHeader')
                          ->subTree
                          ->getElementById('workTitle')
                          ->subTree
                          ->getElementsByTagName("a")->innerText;
    my $author = $item->getElementsByClassName('widget-works-workHeader')
                      ->subTree
                      ->getElementById('workAuthor')
                      ->subTree
                      ->getElementById('workAuthor-activityName')->innerText;
    utf8::decode($main_title);
    utf8::decode($author);
    return sprintf("%s", $main_title . "\n" . $author . "\n\n\n");
}

# 本文処理
sub honbun {
    my $item = shift;
    utf8::decode($item);
    $item =~  m|.*<div class="widget-episodeBody .+? class="blank">(.+)<div id="episodeFooter">.+|s;
    $item =   $1;
    $item =~  s|(class="blank">)<br />|$1|g;
    $item =~  s|<br />|\n|g;
    $item =~  s|<ruby>(.+?)<rt>(.+?)</rt></ruby>|｜$1《$2》|g;
    $item =~  s|<em>(.+?)</em>|［＃傍点］$1［＃傍点終わり］|g;
    $item =~  s|<.*?>||g;
    $item =~  s|^\s+$||gm;
    $item =~  s|！！|!!|g;
    $item =~  s|！？|!\?|g;
#    $item =~ tr|\x{ff5e}|\x{301c}|; #全角チルダ->波ダッシュ
    return $item;
}
sub get_all {
    my $index = shift;
    my $count = scalar(@$index);
    my $item;
    for ( my $i = 0; $i < $count; $i++) {
        my $text = &get_contents( scalar(@$index[$i]->[1]) );
        $text = &honbun( $text );
        my $title = scalar(@$index[$i]->[0]);
        my $time = &timeepoch( scalar(@$index[$i]->[2]) );
        $item = &honbun_formater( $text, $title );
        print STDERR encode($charcode, "success:: $time : $title \n");
        print encode($charcode, $item);
    }
}

sub honbun_formater  {
    my ($text, $title) = @_;
    my $item;
    my $midasi = "\n［＃中見出し］" . $title . "［＃中見出し終わり］\n\n\n";
    $item = $kaipage . $separator . $midasi . $text . "\n\n" . $separator;
    return $item;
}

# YYYY.MM.DD -> epoch time.
sub epochtime {
    my $item = shift;
    my ($year, $month, $day) = split(/-/, $item);
    timelocal(0, 0, 0, $day, $month-1, $year-1900);
}

# epochtime -> YYYY.MM.DD
sub timeepoch {
    my $item =shift;
    my ($mday,$month,$year) = (localtime($item))[3,4,5];
    sprintf("%4d.%02d.%02d", $year+1900, $month+1, $mday);
}

#コマンドラインの取得
sub getopt() {
    GetOptions(
               "chklist|c=s" => \$chklist,
               "savedir|s=s" => \$savedir,
               "update|u=s"  => \$update,
               "help|h"      => \$show_help
              );
}

sub help {
  print STDERR encode($charcode,
        "kakuyomu-dl.pl  (c) 2017 ◆.nITGbUipI\n" .
        "Usage: kakuyomu-dl.pl [options]  [目次url] > [保存ファイル]\n".
        "\tカクヨム投稿小説ダウンローダ\n".
        "\tまとめてダウンロードし標準出力に出力する。\n".
        "\n".
        "\tOption:\n".
        "\t\t-c|--chklist\n".
        "\t\t\t引数に指定したリストを与えると巡回チェックし、\n".
        "\t\t\t新規追加されたデータだけをダウンロードする。\n".
        "\t\t-s|--savedir\n".
        "\t\t\t保存先ディレクトリを指定する。\n".
        "\t\t\t保存先にサブディレクトリを作って個別に保存される。\n".
        "\t\t-u|--update\n".
        "\t\t\tYY-MM-DD形式の日付を与えると、その日付以降の\n".
        "\t\t\tデータだけをダウンロードする。\n".
        "\t\t-h|--help\n".
        "\t\t\tこのテキストを表示する。\n"
      );
  exit 0;
}

# リスト読み込み
sub load_list {
    my $file_name = shift;
    my $LIST;
    my (@item, @list);
    my %hash;
    my $oldsep = $/;
    $/ = "";                    # セパレータを空行に。段落モード
    open ( $LIST, "<:encoding($charcode)" ,"$file_name") or die "$!";
    while (my $line = <$LIST>) {
        push(@item, $line);
    }
    close($LIST);
    $/ = $oldsep;
    # レコード処理
    for (my $i =0; $i <= $#item; $i++) {
        my @record = split('\n', $item[$i]);
        foreach my $field (@record) {
            if ($field =~ /^(title|file_name|url|update)/) {
                my ($key, $value) = split(/=/, $field);
                $key   =~ s/ *//g;
                $value =~ s/^ *//g;
                $value =~ s/"//g;
                if ($value eq "") {
                    print STDERR encode($charcode, "Err:: $field\n");
                    exit 0;
                }
                $hash{$key} = $value; #ハッシュキーと値を追加。
            }
        }
        if ($hash{'title'}) {
            $list[$i] = {%hash}; # ハッシュを配列に格納
        }
        undef %hash;
    }
    undef @item;                #メモリ開放
    return @list;
}

sub save_list {
  my($path, $list) = @_;
  open(STDOUT, ">:encoding($charcode)", $path);
  foreach my $row (@$list) {
    print encode($charcode,
                 "title = " .     $row->{'title'} .     "\n" .
                 "file_name = " . $row->{'file_name'} . "\n" .
                 "url = " .       $row->{'url'} .       "\n" .
                 "update = " .    $row->{'update'} . "\n\n\n"
                 );
  }
  close($path);
}

sub get_path {
    my ($path, $name) = @_;
    my $fullpath;
    if ( -d $path ) {
        $fullpath = File::Spec->catfile($path, $name);
    }
    else {
        require File::Path;
        File::Path::make_path( $path );
        $fullpath = File::Spec->catfile($path, $name);
        print STDERR encode($charcode, "mkdir :: $fullpath\n");
    }
    return $fullpath;
}

sub jyunkai_save {
    my $check_list = shift;
    my $count = @$check_list;
    my $path;
    my $save_file;
    for (my $i = 0; $i < $count; $i++) {
        my $fname = $check_list->[$i]->{'file_name'};
        my $url   = $check_list->[$i]->{'url'};
        my $title = $check_list->[$i]->{'title'};
        my $time  = $check_list->[$i]->{'update'};
        if ( defined($time) ) {
            $last_date = &epochtime( $time );
            $update = 1;
        }
        $base_path = File::Spec->catfile( $savedir, $fname );
        $save_file = &get_path($base_path, $fname) . ".txt";
        open(STDOUT, ">>:encoding($charcode)", $save_file);
        my $body = &get_contents( $url );
        my $dl_list = &novel_index( $body ); # 目次作成
        if (@$dl_list) {
            print STDERR encode($charcode, "START :: " . $title . "\n");
            unless ($update) {
                print encode($charcode, &header( $body ) );
            }
            &get_all( $dl_list );
            my $num = scalar(@$dl_list) -1;
            # 最後の更新日をcheck listに入れる。
            $check_list->[$i]->{update} = &timeepoch( $dl_list->[$num]->[2] );
        }
        else {
            print STDERR encode($charcode, "No Update :: " . $title . "\n");
        }
        $base_path = undef;
        $last_date = undef;
        $update = undef;
    }
    close($save_file);
    &save_list( $chklist, $check_list );
}

#main
{
    my $url;
    &getopt;

    if ($chklist) {
        unless ($savedir) {
            $savedir = Cwd::getcwd();
        }
        #	print "$chklist\n";
        my @check_list = &load_list( $chklist );
        &jyunkai_save( \@check_list );
        exit 0;
    }

    if ($update) {
        if ($update =~ m|\d{2}-\d{2}-\d{2}| ) {
            $last_date = "20" . $update;
            $last_date = &epochtime( $last_date);
        }
        else {
            print STDERR encode($charcode,
                                "YY-MM-DD の形式で入力してください\n"
                               );
            exit 0;
        }
    }

  if (@ARGV == 1) {
      if ($ARGV[0] =~ m|$url_prefix/works/\d{19}$|) {
          $url = $ARGV[0];
          my $body = &get_contents( $url );
          my $list = &novel_index( $body ); # 目次作成
          unless ($update) {
              print encode($charcode, &header( $body ) );
          }
          &get_all( $list );
      }
      elsif ($ARGV[0] =~ m|$url_prefix.+/episodes/|) {
          print STDERR encode($charcode,
                              "個別ページダウンロード未対応\n"
                             );
      }
      else {
          print STDERR encode($charcode,
                              "URLの形式が、『" .
                              "$url_prefix/works/19桁の数字" .
                              "』\nと違います" . "\n"
                             );
      }
  }
  else {
      &help;
      exit 0;
  }

  if ($show_help) {
      &help;
      exit 0;
  }

}
