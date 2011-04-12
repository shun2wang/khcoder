package gui_window::word_ass;
use base qw(gui_window);
use vars qw($filter);

use Tk;
use strict;

use gui_widget::optmenu;
use kh_cod::asso;

my $order_name;

#-------------#
#   GUI作製   #
#-------------#

sub _new{
	my $self = shift;
	my $mw = $::main_gui->mw;
	my $win = $self->{win_obj};
	#$win->focus;
	$win->title($self->gui_jt('関連語探索'));
	#$self->{win_obj} = $win;
	
	#--------------------#
	#   検索オプション   #
	
	my $lf = $win->LabFrame(
		-label => 'Search Entry',
		-labelside => 'acrosstop',
		-borderwidth => 2,
	)->pack(-fill => 'x');

	my $left = $lf->Frame()->pack(-side => 'left', -fill => 'x', -expand => 1);
	my $right = $lf->Frame()->pack(-side => 'right');
	
	# コード選択
	$left->Label(
		-text => $self->gui_jchar('・コード選択'),
		-font => "TKFN"
	)->pack(-anchor => 'w');
	
	$self->{clist} = $left->Scrolled(
		'HList',
		-scrollbars       => 'osoe',
		-header           => '0',
		-itemtype         => 'text',
		-font             => 'TKFN',
		-columns          => '1',
		-padx             => '2',
		-height           => '6',
		-width            => '20',
		-background       => 'white',
		-selectforeground => 'brown',
		-selectbackground => 'cyan',
		-selectmode       => 'extended',
		-command          => sub{ $self->search; },
		-browsecmd        => sub{ $self->clist_check; },
	)->pack(-anchor => 'w', -padx => '4',-pady => '2', -fill => 'both',-expand => 1);

	# コーディングルール・ファイル
	my %pack0 = (
			-anchor => 'w',
	);
	$self->{codf_obj} = gui_widget::codf->open(
		parent   => $right,
		command  => sub{$self->read_code;},
		#r_button => 1,
		pack     => \%pack0,
	);

	# 直接入力フレーム
	my $f3 = $right->Frame()->pack(-fill => 'x', -pady => 6);
	$self->{direct_w_l} = $f3->Label(
		-text => $self->gui_jchar('直接入力：'),
		-font => "TKFN"
	)->pack(-side => 'left');

	$self->{direct_w_o} = gui_widget::optmenu->open(
		parent  => $f3,
		pack    => {-side => 'left'},
		options =>
			[
				['and'  , 'and' ],
				['or'   , 'or'  ],
				['code' , 'code']
			],
		variable => \$self->{opt_direct},
	);

	$self->{direct_w_e} = $f3->Entry(
		-font       => "TKFN",
	)->pack(-side => 'left', -padx => 2,-fill => 'x',-expand => 1);
	$self->{direct_w_e}->bind(
		"<Key>",
		[\&gui_jchar::check_key_e,Ev('K'),\$self->{direct_w_e}]
	);
	$win->bind('Tk::Entry', '<Key-Delete>', \&gui_jchar::check_key_e_d);
	$self->{direct_w_e}->bind("<Key-Return>",sub{$self->search;});

	# 各種オプション
	my $f2 = $right->Frame()->pack(-fill => 'x',-pady => 2);

	$self->{btn_search} = $f2->Button(
		-font    => "TKFN",
		-text    => $self->gui_jchar('集計'),
		-command => sub{ $win->after(10,sub{$self->search;});}
	)->pack(-side => 'right',-padx => 4);
	$win->Balloon()->attach(
		$self->{btn_search},
		-balloonmsg => '"Shinf + Enter"',
		-font       => "TKFN"
	);

	$f2->Label(-text => '   ')->pack(-side => 'right');

	my %pack = (
			-anchor => 'w',
			-pady   => 1,
			-side   => 'right'
	);
	$self->{tani_obj} = gui_widget::tani->open(
		parent => $f2,
		pack   => \%pack
	);
	$self->{l_c_2} = $f2->Label(
		-text => $self->gui_jchar('集計単位：'),
		-font => "TKFN"
	)->pack(-anchor => 'w', -side => 'right');

	$f2->Label(-text => '  ')->pack(-side => 'right');

	$self->{opt_w_method1} = gui_widget::optmenu->open(
		parent  => $f2,
		pack    => {-pady => '1', -side => 'right'},
		options =>
			[
				[$self->gui_jchar('AND検索'), 'and'],
				[$self->gui_jchar('OR検索') , 'or']
			],
		variable => \$self->{opt_method1},
	);

	#--------------#
	#   検索結果   #
	
	my $rf = $win->LabFrame(
		-label => 'Result',
		-labelside => 'acrosstop',
		-borderwidth => 2,
	)->pack(-fill => 'both',-expand => 'yes',-anchor => 'n');

	$self->{rlist} = $rf->Scrolled(
		'HList',
		-scrollbars       => 'osoe',
		-header           => 1,
		-itemtype         => 'text',
		-font             => 'TKFN',
		-columns          => 6,
		-padx             => 2,
		-background       => 'white',
		-selectforeground => 'brown',
		-selectbackground => 'cyan',
		-selectmode       => 'extended',
		-height           => 10,
		-command          => sub {$self->conc;}
	)->pack(-fill =>'both',-expand => 'yes');

	$self->{rlist}->header('create',0,-text => 'N');
	$self->{rlist}->header('create',1,-text => $self->gui_jchar('抽出語'));
	$self->{rlist}->header('create',2,-text => $self->gui_jchar('品詞'));
	$self->{rlist}->header('create',3,-text => $self->gui_jchar('全体'));
	$self->{rlist}->header('create',4,-text => $self->gui_jchar('共起'));
	#$self->{rlist}->header('create',5,-text => $self->gui_jchar('条件付き確立'));
	$self->{rlist}->header('create',5,-text => $self->gui_jchar(' ソート'));

	my $f5 = $rf->Frame()->pack(-fill => 'x', -pady => 2);
	
	$self->{status_label} = $f5->Label(
		-text       => 'Ready.',
		-font       => "TKFN",
		-foreground => 'blue'
	)->pack(-side => 'right');

	$self->{copy_btn} = $f5->Button(
		-font    => "TKFN",
		-text    => $self->gui_jchar('コピー'),
		#-width   => 8,
		-command => sub{ $win->after(10,sub{gui_hlist->copy($self->{rlist});});},
		-borderwidth => 1
	)->pack(-side => 'left');

	$self->win_obj->bind(
		'<Control-Key-c>',
		sub{ $self->{copy_btn}->invoke; }
	);
	$self->win_obj->Balloon()->attach(
		$self->{copy_btn},
		-balloonmsg => 'Ctrl + C',
		-font => "TKFN"
	);

	$f5->Button(
		-font    => "TKFN",
		#-width   => 8,
		-text    => $self->gui_jchar('コンコーダンス'),
		-command => sub{ $win->after(10,sub{$self->conc;});},
		-borderwidth => 1
	)->pack(-side => 'left',-padx => 2);

	$f5->Label(
		-text => $self->gui_jchar(' ソート：'),
		-font => "TKFN",
	)->pack(-side => 'left');

	gui_widget::optmenu->open(
		parent  => $f5,
		pack    => {-side => 'left'},
		options =>
			[
				[$self->gui_jchar('確率差') , 'sa'  ],
				[$self->gui_jchar('確率比') , 'hi'  ],
				['Jaccard'                  , 'jac' ],
				['Ochiai'                   , 'ochi'],
				#[$self->gui_jchar('χ2乗') , 'chi'],
			],
		variable => \$self->{opt_order},
		command  => sub{$self->display;}
	)->set_value('jac');

	$order_name = {
		'sa'  => $self->gui_jchar('確率差'),
		'hi'  => $self->gui_jchar('確率比'),
		'jac' => 'Jaccard',
		'ochi'=> 'Ochiai',
	};

	$f5->Label(
		-text => $self->gui_jchar(' '),
		-font => "TKFN",
	)->pack(-side => 'left');

	$self->{btn_prev} = $f5->Button(
		-text        => $self->gui_jchar('フィルタ設定'),
		-font        => "TKFN",
		-command     =>
			sub{
				gui_window::word_ass_opt->open;
			},
		-borderwidth => 1,
		-state       => 'normal',
	)->pack(-side => 'left',-padx => 2);

	$self->{hits_label} = $f5->Label(
		-text       => $self->gui_jchar('  文書数：0'),
		-font       => "TKFN",
	)->pack(-side => 'left',);

	$self->win_obj->bind(
		'<FocusIn>',
		sub { $self->activate; }
	);

	#--------------------------#
	#   フィルタ設定の初期化   #

	$filter = undef;
	$filter->{limit}   = 200;                  # LIMIT数
	$filter->{min_doc} = 1;                    # 最低文書数
	my $h = mysql_exec->select("               # 品詞によるフィルタ
		SELECT name, khhinshi_id
		FROM   hselection
		WHERE  ifuse = 1
	",1)->hundle;
	while (my $i = $h->fetch){
		if (
			   $i->[0] =~ /B$/
			|| $i->[0] eq '否定助動詞'
			|| $i->[0] eq '形容詞（非自立）'
		){
			$filter->{hinshi}{$i->[1]} = 0;
		} else {
			$filter->{hinshi}{$i->[1]} = 1;
		}
	}
	
	return $self;
}

sub start{
	my $self = shift;
	$self->read_code;
	$self->clist_check;
}

#------------------------------------#
#   ルールファイルの更新をチェック   #

sub activate{
	my $self = shift;
	return 1 unless $self->{codf_obj};
	return 1 unless -e $self->cfile;
	return 1 unless $self->{timestamp};
	
	unless ( ( stat($self->cfile) )[9] == $self->{timestamp} ){
		print "reload: ".$self->cfile."\n";
		my @selected = $self->{clist}->infoSelection;
		$self->read_code;
		$self->{clist}->selectionClear;
		foreach my $i (@selected){
			$self->{clist}->selectionSet($i)
				if $self->{clist}->info('exists', $i);
		}
		$self->clist_check;
	}
	return $self;
}

#----------------------------#
#   ルールファイル読み込み   #

sub read_code{
	my $self = shift;
	
	$self->{clist}->delete('all');
	
	# 「直接入力」を追加
	$self->{clist}->add(0,-at => 0);
	$self->{clist}->itemCreate(
		0,
		0,
		-text  => $self->gui_jchar('＃直接入力'),
	);
	#$self->{clist}->selectionClear;
	$self->{clist}->selectionSet(0);

	# ルールファイルを読み込み
	unless (-e $self->cfile ){
		$self->{code_obj} = kh_cod::asso->new;
		return 0;
	}
	
	$self->{timestamp} = ( stat($self->cfile) )[9];
	my $cod_obj = kh_cod::asso->read_file($self->cfile);
	unless (eval(@{$cod_obj->codes})){
		$self->{code_obj} = kh_cod::asso->new;
		return 0;
	}
	
	my $row = 1;
	foreach my $i (@{$cod_obj->codes}){
		$self->{clist}->add($row,-at => "$row");
		$self->{clist}->itemCreate(
			$row,
			0,
			-text  => $self->gui_jchar($i->name),
		);
		++$row;
	}
	$self->{code_obj} = $cod_obj;
	
	# 「コード無し」を付与
	$self->{clist}->add($row,-at => "$row");
	$self->{clist}->itemCreate(
		$row,
		0,
		-text  => $self->gui_jchar('＃コード無し'),
	);
	
	gui_hlist->update4scroll($self->{clist});
	
	$self->clist_check;
	return $self;
}

#----------------------------------#
#   「直接入力」のon/off切り替え   #

sub clist_check{
	my $self = shift;
	my @s = $self->{clist}->info('selection');
	
	if ( @s && $s[0] eq '0' ){
		$self->{direct_w_l}->configure(-foreground => 'black');
		$self->{direct_w_o}->configure(-state => 'normal');
		$self->{direct_w_e}->configure(-state => 'normal');
		$self->{direct_w_e}->configure(-background => 'white');
		$self->{direct_w_e}->focus;
	} else {
		$self->{direct_w_l}->configure(-foreground => 'gray');
		$self->{direct_w_o}->configure(-state => 'disable');
		$self->{direct_w_e}->configure(-state => 'disable');
		$self->{direct_w_e}->configure(-background => 'gray');
	}
	
	my $n = @s;
	if (  $n >= 2) {
		$self->{opt_w_method1}->configure(-state => 'normal');
	} else {
		$self->{opt_w_method1}->configure(-state => 'disable');
	}
}


#--------------#
#   検索実行   #
#--------------#

sub search{
	my $self = shift;
	$self->activate;
	
	# 選択のチェック
	my @selected = $self->{clist}->info('selection');
	unless (@selected){
		my $win = $self->win_obj;
		gui_errormsg->open(
			type   => 'msg',
			msg    => 'コードが選択されていません',
			window => \$win,
		);
		return 0;
	}
	
	# ラベルの変更
	$self->{hits_label}->configure(-text => $self->gui_jchar('  文書数： 0'));
	$self->{status_label}->configure(
		-foreground => 'red',
		-text => 'Searching...'
	);
	$self->{rlist}->delete('all');
	$self->win_obj->update;
	sleep (0.01);
	
	
	# 直接入力部分の読み込み
	$self->{code_obj}->add_direct(
		mode => $self->gui_jg( $self->{opt_direct} ),
		raw  => $self->gui_jg( $self->{direct_w_e}->get ),
	);
	
	# 検索ロジックの呼び出し（検索実行）
	my $query_ok = $self->{code_obj}->asso(
		selected => \@selected,
		tani     => $self->tani,
		method   => $self->{opt_method1},
	);
	
	$self->{status_label}->configure(
		-foreground => 'blue',
		-text => 'Ready.'
	);
	
	if ($query_ok){
		$self->display;
	}
	return $self;
}

#------------------------#
#   検索結果の書き出し   #

sub display{
	my $self = shift;
	
	unless ( $self->{code_obj}          ) {return undef;}
	unless ( $self->{code_obj}->doc_num ) {return undef;}
	
	# HListの更新
	$self->{rlist}->headerConfigure(5,-text,$order_name->{$self->{opt_order}});
	
	$self->{result} = $self->{code_obj}->fetch_results(
		order  => $self->{opt_order},
		filter => $filter,
	);

	my $numb_style = $self->{rlist}->ItemStyle(
		'text',
		-anchor => 'e',
		-background => 'white',
		-font => "TKFN"
	);

	$self->{rlist}->delete('all');
	if ($self->{result}){
		my $row = 0;
		foreach my $i (@{$self->{result}}){
			$self->{rlist}->add($row,-at => "$row");
			$self->{rlist}->itemCreate(           # 順位
				$row,
				0,
				-text  => $row + 1,
				-style => $numb_style
			);
			$self->{rlist}->itemCreate(           # 単語
				$row,
				1,
				-text  => $self->gui_jchar($i->[0]),
			);
			$self->{rlist}->itemCreate(           # 品詞
				$row,
				2,
				-text  => $self->gui_jchar($i->[1]),
			);
			$self->{rlist}->itemCreate(           # 全体
				$row,
				3,
				-text  => " $i->[2]"." ("."$i->[3]".")",
				-style => $numb_style
			);
			$self->{rlist}->itemCreate(           # 共起
				$row,
				4,
				-text  => " $i->[4]"." ("."$i->[5]".")",
				-style => $numb_style
			);
			#$self->{rlist}->itemCreate(           # 条件付き確立
			#	$row,
			#	5,
			#	-text  => "$i->[5]",
			#	-style => $numb_style
			#);
			$self->{rlist}->itemCreate(           # Sort
				$row,
				5,
				-text  => " ".sprintf("%.4f",$i->[6]),
				-style => $numb_style
			);
			++$row;
		}
	} else {
		$self->{result} = [];
	}
	
	# ラベルの更新
	my $num_total = $self->{code_obj}->doc_num;
	gui_hlist->update4scroll($self->{rlist});
	$self->{hits_label}->configure(-text => $self->gui_jchar("  文書数： $num_total"));

	return $self;
}

#----------------------------#
#   コンコーダンス呼び出し   #
#----------------------------#
sub conc{
	use gui_window::word_conc;
	my $self = shift;

	# 変数取得
	my @selected = $self->{rlist}->infoSelection;
	unless(@selected){
		return;
	}
	my $selected = $selected[0];
	my ($query, $hinshi);
	$query = $self->gui_jchar($self->{result}->[$selected][0]);
	$hinshi = $self->gui_jchar($self->{result}->[$selected][1]);
	
	# コンコーダンスの呼び出し
	my $conc = gui_window::word_conc->open;
	$conc->entry->delete(0,'end');
	$conc->entry4->delete(0,'end');
	$conc->entry2->delete(0,'end');
	$conc->entry->insert('end',$query);
	$conc->entry4->insert('end',$hinshi);
	$conc->search;

}

#--------------#
#   アクセサ   #
#--------------#

sub last_words{
	my $self = shift;
	return $self->{last_words};
}

sub cfile{
	my $self = shift;
	$self->{codf_obj}->cfile;
}

sub tani{
	my $self = shift;
	return $self->{tani_obj}->tani;
}

sub win_name{
	return 'w_doc_ass';
}

1;