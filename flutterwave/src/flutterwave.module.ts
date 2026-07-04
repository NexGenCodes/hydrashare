import { CacheModule, Module } from "@nestjs/common";
import { ConfigurableModuleClass } from "./interface";
import AxiosService from "./axios.service";
import { FlutterwaveService } from "./flutterwave.service";
import AirtimeService from "./airtime/airtime.service";
import BankService from "./bank/bank.service";
import DataService from "./wifi/wifi.service";
import ElectricityService from "./electricity/electricity.service";
import MiscellaneousService from "./misc/misc.service";
import TelevisionService from "./television/television.service";
import TollService from "./toll/toll.service";
import WifiService from "./wifi/wifi.service";
import ResponseService from "./response/response.service";

@Module({
  imports: [
    CacheModule.register({
      ttl: 43200000,
    }),
  ],
  providers: [
    FlutterwaveService,
    AxiosService,
    AirtimeService,
    BankService,
    DataService,
    ElectricityService,
    MiscellaneousService,
    TelevisionService,
    TollService,
    WifiService,
    ResponseService
  ],
  exports: [FlutterwaveService],
})
export class FlutterwaveModule extends ConfigurableModuleClass {}
