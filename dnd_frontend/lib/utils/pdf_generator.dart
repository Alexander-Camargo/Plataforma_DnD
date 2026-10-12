import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import '../models/models.dart';

class PdfGenerator {
  static String _stripAccents(String s) {
    const withDia = 'áéíóúñÁÉÍÓÚÑ';
    const withoutDia = 'aeiounAEIOUN';
    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], withoutDia[i]);
    }
    return s;
  }

  static Future<void> generateCharacterSheet(BuildContext context, Character char) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generando PDF... por favor espera.')),
    );

    try {
      pw.Font? baseFont;
      pw.Font? boldFont;
      try {
        baseFont = await PdfGoogleFonts.robotoRegular();
        boldFont = await PdfGoogleFonts.robotoBold();
      } catch (e) {
        debugPrint('Error cargando Google Fonts para PDF: $e');
      }

      final pdf = pw.Document(
        theme: baseFont != null 
          ? pw.ThemeData.withFont(base: baseFont, bold: boldFont)
          : pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
      );

      final stats = char.sheet['stats'] as Map<String, dynamic>? ?? {};
      final mods = char.sheet['modifiers'] as Map<String, dynamic>? ?? {};
      final bg = char.sheet['background'] as Map<String, dynamic>? ?? {};
      final saves = char.sheet['saves'] as Map<String, dynamic>? ?? {};
      final eq = char.sheet['equipment'] as List<dynamic>? ?? [];

      String safeText(String? text) {
        if (text == null) return '';
        if (baseFont == null) return _stripAccents(text);
        return text;
      }

      String mod(String k) {
        final m = (mods[k] as num?)?.toInt() ?? 0;
        return m >= 0 ? '+$m' : '$m';
      }

      pw.Widget sectionTitle(String title) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey700)),
          ),
          child: pw.Text(
            safeText(title.toUpperCase()),
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black),
          ),
        );
      }

      pw.Widget buildStat(String label, String key) {
        return pw.Container(
          width: 50,
          height: 60,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(safeText(label), style: const pw.TextStyle(fontSize: 10)),
              pw.Text(mod(key),
                  style:
                      pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('${stats[key] ?? 10}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        );
      }

      pw.Widget buildListItem(String label, String value,
          {bool isProficient = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(isProficient ? 'X  ' : 'O  ',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(safeText(label), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Text(safeText(value), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 2)),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(safeText(char.name),
                              style: pw.TextStyle(
                                  fontSize: 24, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Nombre del Personaje',
                              style: const pw.TextStyle(
                                  fontSize: 10, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(safeText('Clase y Nivel: ${char.classSlug} ${char.level}')),
                              pw.Text(safeText('Alineamiento: ${bg['alignment'] ?? '-'}')),
                            ],
                          ),
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(safeText('Raza: ${char.race}')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      children: [
                        buildStat('FUE', 'fue'),
                        pw.SizedBox(height: 5),
                        buildStat('DES', 'des'),
                        pw.SizedBox(height: 5),
                        buildStat('CON', 'con'),
                        pw.SizedBox(height: 5),
                        buildStat('INT', 'int'),
                        pw.SizedBox(height: 5),
                        buildStat('SAB', 'sab'),
                        pw.SizedBox(height: 5),
                        buildStat('CAR', 'car'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 15),

                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(border: pw.Border.all()),
                              child: pw.Column(children: [
                                pw.Text('CA', style: const pw.TextStyle(fontSize: 10)),
                                pw.Text('${char.sheet['ac'] ?? 10}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                              ]),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(border: pw.Border.all()),
                              child: pw.Column(children: [
                                pw.Text('INICIATIVA', style: const pw.TextStyle(fontSize: 10)),
                                pw.Text(mod('des'), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                              ]),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(border: pw.Border.all()),
                              child: pw.Column(children: [
                                pw.Text('VELOCIDAD', style: const pw.TextStyle(fontSize: 10)),
                                pw.Text('${char.sheet['speed'] ?? 30} ft', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                              ]),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(border: pw.Border.all()),
                              child: pw.Column(children: [
                                pw.Text(safeText('PG MÁX'), style: const pw.TextStyle(fontSize: 10)),
                                pw.Text('${char.sheet['hp'] ?? 10}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                              ]),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 15),

                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  sectionTitle('Tiradas de Salvación'),
                                  buildListItem('Fuerza', mod('fue'), isProficient: saves['fue'] == true),
                                  buildListItem('Destreza', mod('des'), isProficient: saves['des'] == true),
                                  buildListItem('Constitución', mod('con'), isProficient: saves['con'] == true),
                                  buildListItem('Inteligencia', mod('int'), isProficient: saves['int'] == true),
                                  buildListItem('Sabiduría', mod('sab'), isProficient: saves['sab'] == true),
                                  buildListItem('Carisma', mod('car'), isProficient: saves['car'] == true),
                                ],
                              ),
                            ),
                            pw.SizedBox(width: 15),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  sectionTitle('Habilidades Principales'),
                                  buildListItem('Acrobacias (Des)', mod('des')),
                                  buildListItem('Atletismo (Fue)', mod('fue')),
                                  buildListItem('Engaño (Car)', mod('car')),
                                  buildListItem('Historia (Int)', mod('int')),
                                  buildListItem('Percepción (Sab)', mod('sab')),
                                  buildListItem('Persuasión (Car)', mod('car')),
                                  buildListItem('Sigilo (Des)', mod('des')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  pw.Container(
                    width: 230,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        sectionTitle('Historia y Rasgos'),
                        pw.Text(safeText('Ideales: ${bg['ideals'] ?? '-'}')),
                        pw.SizedBox(height: 5),
                        pw.Text(safeText('Vínculos: ${bg['bonds'] ?? '-'}')),
                        pw.SizedBox(height: 5),
                        pw.Text(safeText('Defectos: ${bg['flaws'] ?? '-'}')),
                        pw.SizedBox(height: 10),
                        pw.Text(safeText(bg['history'] ?? 'Sin historia escrita.'), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 230,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        sectionTitle('Equipamiento'),
                        if (eq.isEmpty)
                          pw.Text(safeText('Mochila vacía.'), style: const pw.TextStyle(color: PdfColors.grey))
                        else
                          ...eq.map((item) => pw.Text(safeText('• $item'))),
                      ],
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      final fileName = '${safeText(char.name).replaceAll(' ', '_')}_hoja.pdf';

      // Uso directo de dart:html (via universal_html) para forzar la descarga sin depender del plugin nativo.
      // Esto resuelve el error MissingPluginException en web porque no usa channels.
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

    } catch (e) {
      debugPrint('Error al generar PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
