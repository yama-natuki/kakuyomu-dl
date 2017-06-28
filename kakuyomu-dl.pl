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
my ($main_title, $author );
my $chapter_title;
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
    my $tree = HTML::TreeBuilder->new;
    $tree->no_space_compacting;
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
        my $title = $subtree->getElementsByClassName('widget-toc-episode-titleLabel')
                            ->innerText;
        my $update = $subtree->getElementsByTagName('time')->attributes->{datetime};
        print "$update:  $title :: $url\n";
        $url_list->[$count] = [$title, $url, $update]; # タイトル、url、公開日
        $count++;
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
        "\t\t\tYY.MM.DD形式の日付を与えると、その日付以降の\n".
        "\t\t\tデータだけをダウンロードする。\n".
        "\t\t-h|--help\n".
        "\t\t\tこのテキストを表示する。\n"
      );
  exit 0;
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
        if ($update =~ m|\d{2}\.\d{2}\.\d{2}| ) {
            $last_date = "20" . $update;
            $last_date = &epochtime( $last_date);
        }
        else {
            print STDERR encode($charcode,
                                "YY.MM.DD の形式で入力してください\n"
                               );
            exit 0;
        }
    }

  if (@ARGV == 1) {
      if ($ARGV[0] =~ m|$url_prefix/works/\d{19}$|) {
          $url = $ARGV[0];
          my $body = &get_contents( $url );
          my $list = &novel_index( $body ); # 目次作成
#          print encode($charcode, &header( $body ) );
#          &get_all( $list );
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
