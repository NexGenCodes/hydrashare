import { Injectable } from "@nestjs/common";
import AirtimeService from "./airtime/airtime.service";
import BankService from "./bank/bank.service";
import DataService from "./wifi/wifi.service";
import ElectricityService from './electricity/electricity.service';
import MiscellaneousService from './misc/misc.service';
import TelevisionService from './television/television.service';
import TollService from './toll/toll.service';
import WifiService from "./wifi/wifi.service";

@Injectable()
export class FlutterwaveService {
  constructor(
    public airtime: AirtimeService,
    public bank: BankService,
    public data: DataService,
    public electricity:ElectricityService,
    public misc:MiscellaneousService,
    public tv:TelevisionService,
    public toll:TollService,
    public wifi:WifiService
  ) {}
}
