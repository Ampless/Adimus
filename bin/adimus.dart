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
    .map((e) => '$PROTOCOL_AND_DOMAIN${e.attributes['href']}');

dom.Element? htmlGetRightTr(List<dom.Element> root) =>
    html.searchFirst(root, (e) => e.outerHtml.startsWith('<table>'));

Future<Iterable<String>> getBaseUrls(String url) async =>
    searchHtml(HtmlParser(await http.get(url)).parse().children, 'einruecken')
        .map((e) => '$PROTOCOL_AND_DOMAIN${e.attributes['href']}');

Future<Map<String, String>> getRealHtml(Iterable<String> urls) async {
  final h = <String, String>{};
  for (final u in urls) {
    print(u);
    final elements = HtmlParser(await http.get(u)).parse().children;
    final subs = searchHtml(elements, 'p-substitute');
    if (subs.isNotEmpty)
      h.addAll(await getRealHtml(htmlGetAnchors(subs.first.children)));
    else
      h[u] = htmlGetRightTr(elements)!.children.last.innerHtml;
  }
  return h;
}

const PROTOCOL_AND_DOMAIN = 'https://www.frag-caesar.de';
const LIST_URL = '$PROTOCOL_AND_DOMAIN/lateinwoerterbuch/beginnend-mit-a.html';
const CACHE_FILE = 'caesar.cache.adimus';

void main() async {
  var dict = <String, String>{};
  final cache = File(CACHE_FILE);
  if (await cache.exists())
    jsonDecode(await cache.readAsString()).forEach((k, v) => dict[k] = v);
  else
    dict = await getRealHtml(await getBaseUrls(LIST_URL));
  dict.removeWhere((k, v) => v.isEmpty);
  dict.forEach((k, v) => dict[k] =
      v.trim().replaceAll('<br>', ' ').replaceAll(RegExp('<.*?>'), ''));
  await cache.writeAsString(jsonEncode(dict));
}
