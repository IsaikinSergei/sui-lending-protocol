/**
Evaluate the value of collateral, and debt
Calculate the borrowing power, health factor for position
*/
module protocol::evaluator {
  use std::vector;
  use std::type_name::{get, TypeName};
  use sui::math;
  use math::mix;
  use math::fr::{Self, Fr};
  use protocol::price;
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use protocol::coin_decimals_registry;
  
  public fun max_borrow_amount<T>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    let collaterals_value = collaterals_value(position, bank, coinDecimalsRegsitry);
    let debts_value = debts_value(position, coinDecimalsRegsitry);
    if (fr::gt(collaterals_value, debts_value)) {
      let coinType = get<T>();
      let netValue = fr::sub(collaterals_value, debts_value);
      let coinPrice = price::get_price(coinType);
      fr::divT(netValue, coinPrice)
    } else {
      0
    }
  }

  public fun max_withdraw_amount<T>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    let maxBorrowAmount = max_borrow_amount<T>(position, bank, coinDecimalsRegsitry);
    let coinType = get<T>();
    let collateralFactor = bank::collateral_factor(bank, coinType);
    mix::div_ifrT(maxBorrowAmount, collateralFactor)
  }

  public fun max_liquidate_amount<T>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    let collaterals_value = collaterals_value(position, bank, coinDecimalsRegsitry);
    let debts_value = debts_value(position, coinDecimalsRegsitry);
    if (fr::gt(collaterals_value, debts_value)) {
      0
    } else {
      let badDebt = fr::sub(debts_value, collaterals_value);
      let coinType = get<T>();
      let coinPrice = price::get_price(coinType);
      fr::divT(badDebt, coinPrice)
    }
  }

  // sum of every collateral usd value
  // value = price x amount x collateralFactor
  fun collaterals_value(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): Fr {
    let collateralTypes = position::collateral_types(position);
    let totalValudInUsd = fr::fr(0, 1);
    let (i, n) = (0u64, vector::length(&collateralTypes));
    while( i < n ) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
      let (collateralAmount, _) = position::debt(position, collateralType);
      let collateralFactor = bank::collateral_factor(bank, collateralType);
      let coinValueInUsd = fr::mul(
        token_value(collateralType, collateralAmount, decimals),
        collateralFactor,
      );
      totalValudInUsd = fr::add(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }

  // sum of every debt usd value
  // value = price x amount
  fun debts_value(
    position: &Position,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): Fr {
    let debtTypes = position::debt_types(position);
    let totalValudInUsd = fr::fr(0, 1);
    let (i, n) = (0u64, vector::length(&debtTypes));
    while( i < n ) {
      let debtType = *vector::borrow(&debtTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, debtType);
      let (debtAmount, _) = position::debt(position, debtType);
      let coinValueInUsd = token_value(debtType, debtAmount, decimals);
      totalValudInUsd = fr::add(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }

  fun token_value(coinType: TypeName, coinAmount: u64, decimals: u8): Fr {
    let price = price::get_price(coinType);
    let decimalAmount = fr::fr(coinAmount, math::pow(10, decimals));
    fr::mul(price, decimalAmount)
  }
}
