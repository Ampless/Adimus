import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

List<dom.Element> searchHtml(List<dom.Element> rootNode, String className) {
  var found = <dom.Element>[];
  for (var e in rootNode) {
    if (e.className.contains(className)) found.add(e);
    found.addAll(searchHtml(e.children, className));
  }
  return found;
}

List<String> htmlGetAnchors(List<dom.Element> root) {
  var found = <String>[];
  for (var e in root) {
    if (e.attributes.containsKey('href'))
      found.add('$PROTOCOL_AND_DOMAIN${e.attributes['href']}');
    found.addAll(htmlGetAnchors(e.children));
  }
  return found;
}

dom.Element htmlGetRightTr(List<dom.Element> root) {
  for (var e in root) {
    if (e.outerHtml.startsWith('<table>')) return e.children.first.children[1];
    var c = htmlGetRightTr(e.children);
    if (c != null) return c;
  }
  return null;
}

HttpClient httpClient = HttpClient();

Future<String> httpGet(String url) async {
  var req = await httpClient.getUrl(Uri.parse(url));
  await req.flush();
  var res = await req.close();
  var bytes = await res.toList();
  var actualBytes = <int>[];
  for (var b in bytes) actualBytes.addAll(b);
  return utf8.decode(actualBytes);
}

Future<List<String>> getBaseUrls(String url) async {
  var s = <String>[];
  for (var e in searchHtml(
      HtmlParser(await httpGet(url)).parse().children, 'einruecken'))
    s.add('$PROTOCOL_AND_DOMAIN${e.attributes['href']}');
  return s;
}

Future<Map<String, String>> getRealHtml(List<String> urls) async {
  var h = <String, String>{};
  for (var u in urls) {
    print('Getting $u');
    var elements = HtmlParser(await httpGet(u)).parse().children;
    var subs = searchHtml(elements, 'p-substitute');
    if (subs.isNotEmpty)
      h.addAll(await getRealHtml(htmlGetAnchors(subs.first.children)));
    else
      h[u] = htmlGetRightTr(elements).children.last.innerHtml;
  }
  return h;
}

const PROTOCOL_AND_DOMAIN = 'https://www.frag-caesar.de';
const LIST_URL = '$PROTOCOL_AND_DOMAIN/lateinwoerterbuch/beginnend-mit-a.html';
const CACHE_FILE = '.caesar.cache.aditus';

void main(List<String> arguments) async {
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
