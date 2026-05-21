import 'package:flutter/material.dart';

import '../models/product.dart';

/// Цена товара: актуальная + зачёркнутая прежняя (как на сайте).
class ProductPriceRow extends StatelessWidget {
  final double price;
  final double? oldPrice;
  final double priceFontSize;
  final double oldPriceFontSize;
  final Color priceColor;
  final MainAxisAlignment alignment;

  const ProductPriceRow({
    super.key,
    required this.price,
    this.oldPrice,
    this.priceFontSize = 17,
    this.oldPriceFontSize = 12,
    this.priceColor = Colors.red,
    this.alignment = MainAxisAlignment.start,
  });

  factory ProductPriceRow.fromProduct(
    Product product, {
    double priceFontSize = 17,
    double oldPriceFontSize = 12,
    Color priceColor = Colors.red,
    MainAxisAlignment alignment = MainAxisAlignment.start,
  }) {
    return ProductPriceRow(
      price: product.price,
      oldPrice: product.oldPrice,
      priceFontSize: priceFontSize,
      oldPriceFontSize: oldPriceFontSize,
      priceColor: priceColor,
      alignment: alignment,
    );
  }

  static bool shouldShowOldPrice(double? oldPrice, double price) {
    if (oldPrice == null) return false;
    return (oldPrice - price).abs() >= 0.01;
  }

  static TextStyle oldPriceTextStyle(double fontSize) {
    const color = Color(0xFF757575);
    return TextStyle(
      fontSize: fontSize,
      color: color,
      decoration: TextDecoration.lineThrough,
      decorationColor: color,
      decorationThickness: 2,
      height: 1.2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Text(
          '${price.toStringAsFixed(0)} с.',
          style: TextStyle(
            fontSize: priceFontSize,
            fontWeight: FontWeight.bold,
            color: priceColor,
          ),
        ),
        if (shouldShowOldPrice(oldPrice, price)) ...[
          SizedBox(width: priceFontSize >= 18 ? 8 : 6),
          Flexible(
            child: Text(
              '${oldPrice!.toStringAsFixed(0)} с.',
              style: oldPriceTextStyle(oldPriceFontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
