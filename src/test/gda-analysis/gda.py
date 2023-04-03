from abc import ABC, abstractmethod
import math

_TIME_SCALAR = 2
_MAX_TIME_EXPONENT = 10

class DiscreteGDA(ABC): 
    @abstractmethod
    def get_cumulative_purchase_price(self, numTotalPurchases, timeSinceStart, quantity):
        pass


class ExponentialDiscreteGDA(DiscreteGDA):
    def __init__(self, initial_price, decay_constant, scale_factor): 
        self.initial_price = initial_price
        self.decay_constant = decay_constant
        self.scale_factor = scale_factor
        
    def get_cumulative_purchase_price(self, num_total_purchases, time_since_start, quantity):
        time_exp = self.decay_constant * time_since_start
        time_exp = min(time_exp, _MAX_TIME_EXPONENT)
        t1 = self.initial_price * math.pow(self.scale_factor, num_total_purchases) # k * (a ** m)
        t2 = math.pow(self.scale_factor, quantity) - 1 # (a ** q) - 1
        t3 = math.pow(_TIME_SCALAR, time_exp) # e ** (lambda * T)
        t4 = self.scale_factor - 1 # alpha - 1
        return t1 * t2 / (t3 * t4)
    
    # k * (e ** (lambda * t)) / alpha ** (m + q - 1) * (alpha ** q - 1) / (alpha - 1) 
    def get_cumulative_selling_price(self, num_total_purchases, time_since_start, quantity):
        time_exp = self.decay_constant * time_since_start
        time_exp = min(time_exp, _MAX_TIME_EXPONENT)
        t1 = self.initial_price * math.pow(_TIME_SCALAR, time_exp)
        t2 = math.pow(self.scale_factor, num_total_purchases + quantity - 1)
        t3 = math.pow(self.scale_factor, quantity) - 1
        t4 = self.scale_factor - 1
        return t1 / t2 * t3 / t4
