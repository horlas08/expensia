import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorDialog extends StatefulWidget {
  final String initialValue;

  const CalculatorDialog({super.key, this.initialValue = ''});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  late String _expression;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _expression = widget.initialValue;
  }

  void _onPressed(String text) {
    setState(() {
      if (text == 'C') {
        _expression = '';
        _result = '';
      } else if (text == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (text == '=') {
        _calculate();
      } else {
        _expression += text;
      }
    });
  }

  void _calculate() {
    try {
      String finalExpression = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      Parser p = Parser();
      Expression exp = p.parse(finalExpression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      setState(() {
        _result = eval.toString();
        // If result is an integer, show it without .0
        if (eval == eval.toInt().toDouble()) {
          _result = eval.toInt().toString();
        }
        _expression = _result;
      });
    } catch (e) {
      setState(() {
        _result = 'Error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cs.surface,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _expression.isEmpty ? '0' : _expression,
                      style: TextStyle(
                        fontSize: 24,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _result,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildButton('7'), _buildButton('8'), _buildButton('9'), _buildButton('÷', color: cs.primary),
                _buildButton('4'), _buildButton('5'), _buildButton('6'), _buildButton('×', color: cs.primary),
                _buildButton('1'), _buildButton('2'), _buildButton('3'), _buildButton('-', color: cs.primary),
                _buildButton('.'), _buildButton('0'), _buildButton('⌫', color: Colors.orange), _buildButton('+', color: cs.primary),
                _buildButton('C', color: Colors.red),
                _buildButton('=', color: cs.primaryContainer, textColor: cs.onPrimaryContainer, isWide: true),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _expression),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, {Color? color, Color? textColor, bool isWide = false}) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: color ?? cs.surfaceContainerHighest.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _onPressed(text),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor ?? (color != null ? Colors.white : cs.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
