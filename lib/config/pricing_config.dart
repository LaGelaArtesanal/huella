class PricingConfig {
  static double basePrice = 100.0;

  static double multiplier30Min = 0.70;
  static double multiplier50Min = 1.00;

  // ✅ NUEVO: Determina el multiplicador según el tamaño de la mascota
  static double getSizeMultiplier(String? size) {
    final s = size?.toLowerCase().trim() ?? '';
    if (s == 'pequeño' || s == 'small' || s == 'chico') return 1.0;
    if (s == 'mediano' || s == 'medium' || s == 'medio') return 1.2;
    if (s == 'grande' || s == 'large' || s == 'gran') return 1.5;
    return 1.0; // Valor por defecto si no se reconoce
  }

  static double calculateFinalPrice({
    required double durationMultiplier,
    String? size,
    double demandMultiplier = 1.0,
  }) {
    double sizeMultiplier = getSizeMultiplier(size);
    return basePrice * durationMultiplier * sizeMultiplier * demandMultiplier;
  }
}