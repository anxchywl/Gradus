// integer hundredths, because 33.34+33.33+33.33 misses 100 as doubles
library;

const int weightScale = 100;

const int completeWeight = 100 * weightScale;

int toHundredths(double percentage) => (percentage * weightScale).round();

double fromHundredths(int hundredths) => hundredths / weightScale;

int sumHundredths(Iterable<double> percentages) {
  var total = 0;
  for (final percentage in percentages) {
    total += toHundredths(percentage);
  }
  return total;
}
