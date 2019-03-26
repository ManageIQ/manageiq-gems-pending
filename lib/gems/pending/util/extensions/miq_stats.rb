require 'more_core_extensions/core_ext/math'

module MiqStats
  def self.slope(x_array, y_array)
    coordinates = x_array.zip(y_array)
    Math.linear_regression(*coordinates)
  end

  def self.solve_for_y(x, m, b)
    Math.slope_y_intercept(x, m, b)
  end

  def self.solve_for_x(y, m, b)
    Math.slope_x_intercept(y, m, b)
  end
end
