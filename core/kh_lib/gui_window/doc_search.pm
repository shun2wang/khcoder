package gui_window::doc_search;
use base qw(gui_window);

use Tk;
use strict;

use gui_window::doc_search::linux;
use gui_window::doc_search::win32;
use gui_widget::optmenu;
use kh_cod::search;

#-------------#
#   GUI作製   #
#-------------#

sub _new{
	my $self = shift;
	my $mw = $::main_gui->mw;
	my $win = $mw->Toplevel;
	#$win->focus;
	$win->title(Jcode->new('文書検索')->sjis);
	$self->{win_obj} = $win;
	
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
		-text => Jcode->new('・コード選択')->sjis,
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
		r_button => 1,
		pack     => \%pack0,
	);

	# 直接入力フレーム
	my $f3 = $right->Frame()->pack(-fill => 'x', -pady => 6);
	$self->{direct_w_l} = $f3->Label(
		text => Jcode->new('直接入力：')->sjis,
		font => "TKFN"
	)->pack(-side => 'left');

	#$self->{direct_w_o} = $f3->Optionmenu(
	#	-options => ['and','or','code'],
	#	-font    => "TKFN",
	#	-width   => 4,
	#	-variable => \$self->{opt_direct},
	#	-borderwidth=> 1,
	#)->pack(-side => 'left');

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
		-text    => Jcode->new('検索')->sjis,
		-command => sub{ $win->after(10,sub{$self->search;});}
	)->pack(-side => 'right',-padx => 4);
	$win->Balloon()->attach(
		$self->{btn_search},
		-balloonmsg => '"Shinf + Enter"',
		-font       => "TKFN"
	);

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
		text => Jcode->new('検索単位：')->sjis,
		font => "TKFN"
	)->pack(anchor => 'w', side => 'right');

	#$self->{opt_w_method1} = $f2->Optionmenu(
	#	-options =>
	#		[
	#			[Jcode->new('AND検索')->sjis => 'and'],
	#			[Jcode->new('OR検索')->sjis  => 'or']
	#		],
	#	-font    => "TKFN",
	#	-width   => 7,
	#	-variable => \$self->{opt_method1},
	#	-borderwidth => 1,
	#)->pack(-pady => '1', -side => 'left');

	$self->{opt_w_method1} = gui_widget::optmenu->open(
		parent  => $f2,
		pack    => {-pady => '1', -side => 'left'},
		options =>
			[
				[Jcode->new('AND検索')->sjis, 'and'],
				[Jcode->new('OR検索')->sjis , 'or']
			],
		variable => \$self->{opt_method1},
	);

	#$f2->Optionmenu(
	#	-options =>
	#		[
	#			[Jcode->new('出現順')->sjis => 'by'],
	#			[Jcode->new('tf順')->sjis  => 'tf']
	#		],
	#	-font    => "TKFN",
	#	-width   => 7,
	#	-variable => \$self->{opt_order},
	#	-borderwidth=> 1,
	#)->pack(-padx => 8);

	gui_widget::optmenu->open(
		parent  => $f2,
		pack    => {-padx => 8, -pady => 1},
		options =>
			[
				[Jcode->new('出現順')->sjis , 'by'],
				[Jcode->new('tf順')->sjis   , 'tf']
			],
		variable => \$self->{opt_order},
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
		-header           => 0,
		-itemtype         => 'text',
		-font             => 'TKFN',
		-columns          => 1,
		-padx             => 2,
		-background       => 'white',
		-selectforeground => 'brown',
		-selectbackground => 'cyan',
		-selectmode       => 'extended',
		-height           => 10,
		-command          => sub {$self->view_doc;}
	)->pack(-fill =>'both',-expand => 'yes');

	my $f5 = $rf->Frame()->pack(-fill => 'x', -pady => 2);
	
	$self->{status_label} = $f5->Label(
		text       => 'Ready.',
		font       => "TKFN",
		foreground => 'blue'
	)->pack(side => 'right');

	$f5->Button(
		-font    => "TKFN",
		-text    => Jcode->new('コピー')->sjis,
		-width   => 8,
		-command => sub{ $win->after(10,sub{$self->copy;});},
		-borderwidth => 1
	)->pack(-side => 'left');

	$f5->Button(
		-font    => "TKFN",
		-width   => 8,
		-text    => Jcode->new('文書表示')->sjis,
		-command => sub{ $win->after(10,sub{$self->view_doc;});},
		-borderwidth => 1
	)->pack(-side => 'left',-padx => 2);

	$f5->Label(
		-text => ' ',
		-font => "TKFN",
	)->pack(-side => 'left');

	$self->{btn_prev} = $f5->Button(
		-text        => Jcode->new('前'.kh_cod::search->docs_per_once)->sjis,
		-font        => "TKFN",
		-command     =>
			sub{
				my $start =
					$self->{current_start} - kh_cod::search->docs_per_once;
				$self->display($start);
			},
		-borderwidth => 1,
		-state       => 'disable',
	)->pack(-side => 'left',-padx => 2);

	$self->{btn_next} = $f5->Button(
		-text        => Jcode->new('次'.kh_cod::search->docs_per_once)->sjis,
		-font        => "TKFN",
		-command     =>
			sub{
				my $start =
					$self->{current_start} + kh_cod::search->docs_per_once;
				$self->display($start);
			},
		-borderwidth => 1,
		-state       => 'disable',
	)->pack(-side => 'left');

	$self->{hits_label} = $f5->Label(
		text       => Jcode->new('  ヒット数：0')->sjis,
		font       => "TKFN",
	)->pack(side => 'left',);
	


	return $self;
}

sub start{
	my $self = shift;
	$self->read_code;
	$self->clist_check;

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
		-text  => Jcode->new('＃直接入力')->sjis,
	);
	$self->{clist}->selectionClear;
	$self->{clist}->selectionSet(0);

	# ルールファイルを読み込み
	unless (-e $self->cfile ){
		$self->{code_obj} = kh_cod::search->new;
		return 0;
	}
	
	my $cod_obj = kh_cod::search->read_file($self->cfile);
	unless (eval(@{$cod_obj->codes})){
		$self->{code_obj} = kh_cod::search->new;
		return 0;
	}
	
	my $row = 1;
	foreach my $i (@{$cod_obj->codes}){
		$self->{clist}->add($row,-at => "$row");
		$self->{clist}->itemCreate(
			$row,
			0,
			-text  => Jcode->new($i->name)->sjis,
		);
		++$row;
	}
	$self->{code_obj} = $cod_obj;
	
	# 「コード無し」を付与
	$self->{clist}->add($row,-at => "$row");
	$self->{clist}->itemCreate(
		$row,
		0,
		-text  => Jcode->new('＃コード無し')->sjis,
	);
	
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
#   文書表示   #
#--------------#

sub view_doc{
	my $self = shift;
	my @selected = $self->{rlist}->infoSelection;
	unless (@selected){
		return;
	}
	my $selected = $selected[0];
	
	my ($t,$w) = $self->{code_obj}->check_a_doc($self->{result}[$selected][0]);
	
	my $view_win = gui_window::doc_view->open;
	$view_win->view(
		doc_id  => $self->{result}[$selected][0],
		tani    => $self->tani,
		parent  => $self,
		kyotyo  => $self->last_words,
		kyotyo2 => $w,
		foot    => $t,
	);
}

sub next{
	my $self = shift;
	my @selected = $self->{rlist}->infoSelection;
	unless (@selected){
		return -1;
	}
	my $selected = $selected[0] + 1;
	my $max = @{$self->{result}} - 1;
	if ($selected > $max){
		$selected = $max;
	}
	my $doc_id = $self->{result}[$selected][0];
	my ($t,$w) = $self->{code_obj}->check_a_doc($doc_id);
	
	$self->{rlist}->selectionClear;
	$self->{rlist}->selectionSet($selected);
	$self->{rlist}->yview($selected);
	my $n = @{$self->{result}};
	if ($n - $selected > 7){
		$self->{rlist}->yview(scroll => -5, 'units');
	}
	
	return (undef,$doc_id,$t,$w);
}

sub prev{
	my $self = shift;
	my @selected = $self->{rlist}->infoSelection;
	unless (@selected){
		return -1;
	}
	my $selected = $selected[0] - 1;
	if ($selected < 0){
		$selected = 0;
	}
	my $doc_id = $self->{result}[$selected][0];
	my ($t,$w) = $self->{code_obj}->check_a_doc($doc_id);
	
	$self->{rlist}->selectionClear;
	$self->{rlist}->selectionSet($selected);
	$self->{rlist}->yview($selected);
	my $n = @{$self->{result}};
	if ($n - $selected > 7){
		$self->{rlist}->yview(scroll => -5, 'units');
	}
	
	return (undef,$doc_id,$t,$w);
}

sub if_next{
	my $self = shift;
	my @selected = $self->{rlist}->infoSelection;
	unless (@selected){
		return 0;
	}
	my $selected = $selected[0] ;
	my $max = @{$self->{result}} - 1;
	if ($selected < $max){
		return 1;
	} else {
		return 0;
	}
}

sub if_prev{
	my $self = shift;
	my @selected = $self->{rlist}->infoSelection;
	unless (@selected){
		return 0;
	}
	my $selected = $selected[0] ;
	if ($selected > 0){
		return 1;
	} else {
		return 0;
	}
}
sub end{
	my $check = 0;
	if ($::main_gui){
		$check = $::main_gui->if_opened('w_doc_view');
	}
	if ( $check ){
		$::main_gui->get('w_doc_view')->close;
	}
}



#--------------#
#   検索実行   #
#--------------#

sub search{
	my $self = shift;
	
	# 選択のチェック
	my @selected = $self->{clist}->info('selection');
	unless (@selected){
		my $win = $self->win_obj;
		gui_errormsg->open(
			type   => 'msg',
			msg    => Jcode->new('コードが選択されていません')->sjis,
			window => \$win,
		);
		return 0;
	}
	
	# ラベルの変更
	$self->{hits_label}->configure(-text => Jcode->new('  ヒット数： 0')->sjis);
	$self->{status_label}->configure(
		-foreground => 'red',
		-text => 'Searcing...'
	);
	$self->{rlist}->delete('all');
	$self->win_obj->update;
	sleep (0.01);
	
	
	# 直接入力部分の読み込み
	$self->{code_obj}->add_direct(
		mode => $self->{opt_direct},
		raw  => $self->{direct_w_e}->get,
	);
	
	# 検索ロジックの呼び出し（検索実行）
	my $query_ok = $self->{code_obj}->search(
		selected => \@selected,
		tani     => $self->tani,
		method   => $self->{opt_method1},
		order    => $self->{opt_order},
	);
	
	$self->{status_label}->configure(
		-foreground => 'blue',
		-text => 'Ready.'
	);
	
	if ($query_ok){
		$self->{last_words} = $self->{code_obj}->last_search_words;
		$self->display(1);
	}
	return $self;
}

#------------------------#
#   検索結果の書き出し   #

sub display{
	my $self = shift;
	my $start = shift;
	$self->{current_start} = $start;

	# HListの更新
	unless ( $self->{code_obj} ){return undef;}
	$self->{result}     = $self->{code_obj}->fetch_results($start);
	$self->{rlist}->delete('all');
	if ($self->{result}){
		my $row = 0;
		foreach my $i (@{$self->{result}}){
			$self->{rlist}->add($row,-at => "$row");
			$self->{rlist}->itemCreate(
				$row,
				0,
				-text  => Jcode->new($i->[1])->sjis,
			);
			++$row;
		}
	} else {
		$self->{result} = [];
	}
	
	# ラベルの更新
	my $num_total = $self->{code_obj}->total_hits;
	my $num_disp  = $start + kh_cod::search->docs_per_once - 1;
	my $num_disp2;
	if ($num_total > $num_disp){
		$num_disp2 = $num_disp;
	} else {
		$num_disp2 = $num_total;
	}
	if ($num_total == 0){$start = 0;}
	$self->{rlist}->yview(0);
	$self->{hits_label}->configure(-text => Jcode->new("  ヒット数： $num_total  表示： $start"."-$num_disp2")->sjis);

	# ボタンの更新
	if ($start > 1){
		$self->{btn_prev}->configure(-state => 'normal');
	} else {
		$self->{btn_prev}->configure(-state => 'disable');
	}
	if ($num_total > $num_disp){
		$self->{btn_next}->configure(-state => 'normal');
	} else {
		$self->{btn_next}->configure(-state => 'disable');
	}
	
	return $self;
}

#------------------#
#   文書のコピー   #
#------------------#
sub copy{
	my $self = shift;
	my $class = "gui_window::doc_search::".$::config_obj->os;
	bless $self, $class;
	
	$self->_copy;
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
	return 'w_doc_search';
}

1;
