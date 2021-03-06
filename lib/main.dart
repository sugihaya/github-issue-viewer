import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert'; // http -> json

void main() {
  runApp(MyApp());
}

/// GitHub APIのIssuesを取得する関数
/// カスタムオブジェクトIssueのリストを返す
Future<List<Issue>> fetchIssues(String query) async {
  // リクエストポイント
  var url = Uri.https('api.github.com', 'repos/flutter/flutter/issues', {
    'labels': query,
    'state': 'all',
  });
  // レスポングを取得
  final response = await http.get(url); // 非同期
  // エラー検証
  if (response.statusCode == 200) {
    final resJson = json.decode(response.body);
    final issues = resJson.map<Issue>((res) => Issue.fromJson(res)).toList();
    return issues;
  } else {
    throw Exception('Issues取得に失敗しました。');
  }
}

/// レスポンスのカスタムクラス
/// 表示内容変更時に適宜修正
class Issue {
  final String title; // タイトル
  final String user; // 作成者
  final String state; // 'Open' or 'Closed'
  final int number; // issueナンバー
  final int comments; // コメント数

  // 変更次第追加

  Issue({this.title, this.user, this.state, this.number, this.comments});

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      title: json['title'],
      user: json['user']['login'],
      state: json['state'],
      number: json['number'],
      comments: json['comments'],
    );
  }
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Issue Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'GitHub Issue Viewer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  // 各種コントローラー
  TabController _tabController;
  TextEditingController _textEditingController;

  // タブの表題とlabelを管理
  List<Map<String, String>> _tabs = [
    {'title': '全て', 'query': ''},
    {'query': 'p: webview'},
    {'query': 'p: shared_preferences'},
    {'query': 'waiting for customer response'},
    {'query': 'severe: new feature'},
    {'query': 'p: share'},
  ];

  // 入力ラベルをもとにタブを追加
  void _addTab(String label) {
    setState(() {
      _tabs.add({'query': label}); // labelをリストに追加
      _tabController = _createNewTabController(); // TabBarの更新
      _textEditingController = TextEditingController(); // ダイアログテキストのリセット
      _tabController.animateTo(_tabs.length - 1); // 追加したタブへ移動
    });
  }

  // コントローラの設定用
  TabController _createNewTabController() => TabController(
        vsync: this,
        length: _tabs.length,
      );

  // 各種コントローラーの初期化
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _textEditingController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // タブ追加ボタン
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              showDialog(
                // ダイアログを表示
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('新しいラベルを入力してください'),
                    content: TextField(
                      controller: _textEditingController,
                    ),
                    actions: [
                      TextButton(
                        child: Text('キャンセル'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text('追加'),
                        onPressed: () {
                          String label = _textEditingController.text;
                          _addTab(label);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) {
            // 表題の有無を確認
            if (t.containsKey('title') == true) {
              return Tab(text: t['title']); //表題ありはtitleを指定
            } else {
              return Tab(text: t['query']); // 表題なしはqueryを指定
            }
          }).toList(),
          isScrollable: true,
          unselectedLabelStyle: TextStyle(fontSize: 12.0),
          labelStyle: TextStyle(fontSize: 16.0),
          indicatorWeight: 2,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map(
              (t) => TabPage(query: t['query']),
            )
            .toList(),
      ),
    );
  }
}

/// 各タブページのウィジェット
/// 初期化時にqueryをもとにAPIリクエストを送る
class TabPage extends StatefulWidget {
  final String query;

  const TabPage({
    Key key,
    @required this.query,
  }) : super(key: key);

  @override
  _TabPageState createState() => _TabPageState();
}

/// サブツリーのstateを保持するmixinを使用
/// 各タブの読み込み時にAPIを叩く
/// stateを保持するため、initState()実行済みはそのstateを再利用
class _TabPageState extends State<TabPage> with AutomaticKeepAliveClientMixin {
  Future<List<Issue>> _issues;

  @override
  void initState() {
    super.initState();
    _issues = fetchIssues(widget.query); // GitHub APIでissuesを取得
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<dynamic>(
      future: _issues,
      builder: (context, snapshot) {
        // 待機中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator()); // 待機中
        }
        // リクエストの取得・エラー判定
        if (snapshot.hasData) {
          // リストビューでアイテムを表示
          return ListView.builder(
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                // 各アイテムはカードで表示
                child: _createIssueCard(snapshot.data[index]),
              );
            },
            itemCount: snapshot.data.length,
          );
        } else if (snapshot.hasError) {
          return Text("${snapshot.error}"); // Error時 Status:200 以外
        } else {
          return Text("None");
        }
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  /// issueのstateによって返すアイコンを切り替えるメソッド
  Icon _switchIssueIcon(String state) {
    if (state == 'open') {
      return Icon(
        Icons.info_outline,
        color: Colors.green,
      );
    } else if (state == 'closed') {
      return Icon(
        Icons.check_circle_outline,
        color: Colors.red,
      );
    } else {
      return Icon(
        Icons.help_outline,
        color: Colors.blue,
      );
    }
  }

  /// issueを表示するカードウィジェットを返すメソッド
  /// リスト管理されたIssueオブジェクト一つ一つを描画
  Widget _createIssueCard(Issue issue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              // issueナンバーとコメント数
              children: [
                Text('No.' + issue.number.toString()),
                SizedBox(width: 20), // 余白用
                Row(
                  children: [
                    Icon(Icons.comment),
                    Text(issue.comments.toString()),
                  ],
                ),
              ],
            ),
            Padding(
              // 状態アイコン(open or closed)とタイトル
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  _switchIssueIcon(issue.state),
                  SizedBox(
                    width: 10,
                  ),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      child: Text(
                        issue.title,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              // 作成者
              children: [
                Text('created by ' + issue.user),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
