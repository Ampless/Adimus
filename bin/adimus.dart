import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:html_search/html_search.dart' as html;
import 'package:schttp/schttp.dart';

final http = ScHttpClient();

Iterable<dom.Element> searchHtml(List<dom.Element> root, String className) =>
    html.search(root, (e) => e.className.contains(className));

Iterable<String> htmlGetAnchors(List<dom.Element> root) => html
    .search(root, (e) => e.attributes.containsKey('href'))
    .map((e) => '$endpoint${e.attributes['href']}');

dom.Element? htmlGetRightTr(List<dom.Element> root) =>
    html.searchFirst(root, (e) => e.outerHtml.startsWith('<table>'));

Future<Iterable<String>> getBaseUrls(String url) async =>
    searchHtml(HtmlParser(await http.get(url)).parse().children, 'einruecken')
        .map((e) => '$endpoint${e.attributes['href']}');

Future<Map<String, String>> getRealHtml(Iterable<String> urls) async {
  final h = <String, String>{};
  for (final u in urls) {
    print(u);
    final elements = HtmlParser(await http.get(u)).parse().children;
    final subs = searchHtml(elements, 'p-substitute');
    if (subs.isNotEmpty) {
      h.addAll(await getRealHtml(htmlGetAnchors(subs.first.children)));
    } else {
      h[u] = htmlGetRightTr(elements)!.children.last.innerHtml;
    }
  }
  return h;
}

const endpoint = 'https://www.frag-caesar.de';
const listUrl = '$endpoint/lateinwoerterbuch/beginnend-mit-a.html';
final cache = File('adimus.json');

void main() async {
  final dict = await cache.exists()
      ? Map<String, String>.from(jsonDecode(await cache.readAsString()))
      : await getRealHtml(await getBaseUrls(listUrl));
  dict.removeWhere((k, v) => v.isEmpty);
  dict.forEach((k, v) => dict[k] =
      v.trim().replaceAll('<br>', ' ').replaceAll(RegExp('<.*?>'), ''));
  await cache.writeAsString(jsonEncode(dict));
}
