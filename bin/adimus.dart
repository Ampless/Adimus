import 'dart:io';
import 'package:fhir_yaml/fhir_yaml.dart';
import 'package:html/dom.dart' as dom;
import 'package:html_search/html_search.dart';
import 'package:http/http.dart';
import 'package:yaml/yaml.dart';

Iterable<String> htmlGetAnchors(List<dom.Element> root) => root
    .search((e) => e.attributes.containsKey('href'))
    .map((e) => '$endpoint${e.attributes['href']}');

Future<Iterable<String>> getBaseUrls(String url) async =>
    htmlParse(await get(Uri.parse(url)).then((r) => r.body))
        .search((e) => e.className == 'einruecken')
        .map((e) => '$endpoint${e.attributes['href']}');

Stream<MapEntry<String, String>> words(Iterable<String> urls) async* {
  for (final u in urls) {
    final res = await get(Uri.parse(u));
    print('${res.statusCode} $u');
    if (res.statusCode != 200) {
      continue;
    }
    final elements = htmlParse(res.body);
    final subs = elements.search((e) => e.className == 'p-substitute');
    if (subs.isNotEmpty) {
      yield* words(htmlGetAnchors(subs.first.children));
    } else {
      final table = elements
          .searchFirst((e) => e.outerHtml.startsWith('<table'))!
          .children;
      String searchClassLastInnerClean(String cn) => table
          .search((e) => e.className == cn)
          .last
          .innerHtml
          .replaceAll(RegExp('</?[a-z ="]+>'), ' ')
          .replaceAll(RegExp(' +'), ' ')
          .trim();
      yield MapEntry(
          searchClassLastInnerClean('eh2'), searchClassLastInnerClean('eh'));
    }
  }
}

const endpoint = 'https://www.frag-caesar.de';
const listUrl = '$endpoint/lateinwoerterbuch/beginnend-mit-a.html';
final cache = File('adimus.yaml');

void main() async {
  final dict = await cache.exists()
      ? Map<String, String>.from(loadYaml(await cache.readAsString()))
      : await words(await getBaseUrls(listUrl)).toList().then(Map.fromEntries);
  dict.removeWhere((k, v) => v.isEmpty);
  dict.forEach((k, v) => dict[k] =
      v.trim().replaceAll('<br>', ' ').replaceAll(RegExp('<.*?>'), ''));
  await cache.writeAsString(json2yaml(dict));
}
