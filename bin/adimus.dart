import 'dart:io';
import 'package:fhir_yaml/fhir_yaml.dart';
import 'package:html/dom.dart' as dom;
import 'package:html_search/html_search.dart' as html;
import 'package:schttp/schttp.dart';
import 'package:yaml/yaml.dart';

final http = ScHttpClient();

Iterable<dom.Element> searchClass(List<dom.Element> root, String className) =>
    html.search(root, (e) => e.className == className);

String searchClassLastInnerClean(List<dom.Element> root, String className) =>
    searchClass(root, className)
        .last
        .innerHtml
        .replaceAll(RegExp('</?[a-z ="]+>'), ' ')
        .replaceAll(RegExp(' +'), ' ')
        .trim();

Iterable<String> htmlGetAnchors(List<dom.Element> root) => html
    .search(root, (e) => e.attributes.containsKey('href'))
    .map((e) => '$endpoint${e.attributes['href']}');

Future<Iterable<String>> getBaseUrls(String url) async =>
    searchClass(html.parse(await http.get(url)), 'einruecken')
        .map((e) => '$endpoint${e.attributes['href']}');

Future<Map<String, String>> words(Iterable<String> urls) async {
  final h = <String, String>{};
  for (final u in urls) {
    final elements = html.parse(await http.get(u));
    final subs = searchClass(elements, 'p-substitute');
    if (subs.isNotEmpty) {
      h.addAll(await words(htmlGetAnchors(subs.first.children)));
    } else {
      final table = html
          .searchFirst(elements, (e) => e.outerHtml.startsWith('<table>'))!
          .children;
      final latin = searchClassLastInnerClean(table, 'eh2');
      final german = searchClassLastInnerClean(table, 'eh');
      h[latin] = german;
      print('$latin = $german ($u)');
    }
  }
  return h;
}

const endpoint = 'https://www.frag-caesar.de';
const listUrl = '$endpoint/lateinwoerterbuch/beginnend-mit-a.html';
final cache = File('adimus.yaml');

void main() async {
  final dict = await cache.exists()
      ? Map<String, String>.from(loadYaml(await cache.readAsString()))
      : await words(await getBaseUrls(listUrl));
  dict.removeWhere((k, v) => v.isEmpty);
  dict.forEach((k, v) => dict[k] =
      v.trim().replaceAll('<br>', ' ').replaceAll(RegExp('<.*?>'), ''));
  await cache.writeAsString(json2yaml(dict));
}
