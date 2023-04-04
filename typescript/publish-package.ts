import path from "path";
import dotenv from "dotenv";
import { SuiKit } from "@scallop-dao/sui-kit";
dotenv.config();

(async() => {
  const mnemonics = process.env.MNEMONICS;
  const networkType = (process.env.NETWORK_TYPE || 'devnet') as 'devnet' | 'testnet' | 'mainnet';
  const suiKit = new SuiKit({ mnemonics, networkType });
  const balance = await suiKit.getBalance();
  if (balance.totalBalance <= 3000) {
    await suiKit.requestFaucet();
  }
  // Wait for 3 seconds before publish package
  await new Promise(resolve => setTimeout(() => resolve(true), 3000));

  const packagePath = path.join(__dirname, '../query');
  const result = await suiKit.publishPackage(packagePath);
  console.log('packageId: ' + result.packageId);
})();
