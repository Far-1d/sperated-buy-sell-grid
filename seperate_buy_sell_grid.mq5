//+------------------------------------------------------------------+
//|                                       seperate_buy_sell_grid.mq5 |
//|                                      Copyright 2024, Farid Zarie |
//|                                        https://github.com/Far-1d |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Farid Zarie"
#property link      "https://github.com/Far-1d"
#property version   "1.20"
#property description "Grid EA But sells and buys are opened seperately"
#property description "buys are opened when price goes down and sells vice versa"
#property description "created at 30/9/2024"
#property description "made with ❤ & ️🎮"
#property description ""
#property description ""
#property description "panel upgraded to full potential - info box text fixed"


#define BOX_NAME "info_box"
#define TEXT_NAME "info_text"
#define TRADE_BOX "trade_box"
#define BUY_TEXT "buy_text"
#define SELL_TEXT "sell_text"
#define BALANCE_TEXT "balance_text"
#define EQUITY_TEXT "equity text"

//--- imports
#include <Trade/Trade.mqh>
CTrade      trade;                        // object of CTrade class
#include <Trade\SymbolInfo.mqh>
CSymbolInfo sInfo;

#include <Controls\Dialog.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>
#include <Controls\CheckBox.mqh>

CAppDialog  app;


CCheckBox buy_checkbox;
CEdit buy_step_inp_edit;
CEdit buy_multiplier_inp_edit;
CEdit buy_profit_inp_edit;

CLabel buy_step_inp_label;
CLabel buy_multiplier_inp_label;
CLabel buy_profit_inp_label;

CCheckBox sell_checkbox;
CEdit sell_step_inp_edit;
CEdit sell_multiplier_inp_edit;
CEdit sell_profit_inp_edit;

CLabel sell_step_inp_label;
CLabel sell_multiplier_inp_label;
CLabel sell_profit_inp_label;


CEdit total_profit_inp_edit;
CLabel total_profit_inp_label;
CEdit lot_size_edit;
CLabel lot_size_label;
CButton submit;


int PANEL_W = 500;
int PANEL_H = 180;

//--- enums
enum lot_inc_mtd{
   aggressive,                // Aggresive
   constant                   // Constant
};
enum profit_mtds{
  Profit,                     // Profit only
  commission,                 // Profit + Commission
  swap                        // Profit + Commission + Swap 
};


//--- inputs
input group "Grid Buy Config";
input bool           enable_buy_inp       = false;             // Enable Buy ?
input int            buy_step_inp         = 20;                // Buy Step   pip
input double         buy_multiplier_inp   = 50;                // Buy Lot Size Increase %
input lot_inc_mtd    buy_lot_mtd_inp      = aggressive;        // Buy Lot Size Increase Method
input int            buy_profit_inp       = 5;                 // Profit of Buy Trades  $

input group "Grid Sell Config";
input bool           enable_sell_inp      = false;             // Enable Sell ?
input int            sell_step_inp        = 20;                // Sell Step   pip
input double         sell_multiplier_inp  = 50;                // Sell Lot Size Increase %
input lot_inc_mtd    sell_lot_mtd_inp     = aggressive;        // Sell Lot Size Increase Method
input int            sell_profit_inp      = 5;                 // Profit of Sell Trades  $

input group "Common Config";
input int            total_profit_inp  = 6;                 // Total Profit
input profit_mtds    profit_mtd_inp    = Profit;            // Profit Calculation Method
input double         lot_size_inp      = 0.1;               // Initial Lot Size

input group "EA Config";
input int            Magic             = 301;
input double         max_sway          = 1.0;               // Max Entry Level Price difference %
input int            max_spread        = 25;                // Maximum Spread of Symbol (used to find trades)
input color          box_clr           = clrDarkSlateGray;  // Box Color
input color          text_clr          = clrWhite;          // Text Color
input int            box_time          = 10;                // Box Visible Time (per candle)
input string         user_comment      = "grid position";   // Position Comment
input string         balance_time      = "12:00";           // When to Check Balance


//--- main setting 
bool           enable_buy       = enable_buy_inp;
int            buy_step         = buy_step_inp;
double         buy_multiplier   = buy_multiplier_inp;
lot_inc_mtd    buy_lot_mtd      = buy_lot_mtd_inp;
int            buy_profit       = buy_profit_inp;

bool           enable_sell      = enable_sell_inp;
int            sell_step        = sell_step_inp;
double         sell_multiplier  = sell_multiplier_inp;
lot_inc_mtd    sell_lot_mtd     = sell_lot_mtd_inp;
int            sell_profit      = sell_profit_inp;

profit_mtds    profit_mtd       = profit_mtd_inp;
int            total_profit     = total_profit_inp;
double         lot_size         = lot_size_inp;


//--- globals
string positions_data [][6];                       // stores every grid position data (ticket, price, symbol, type, lot)
double old_lot_grid_value_buy  = lot_size;
double old_lot_grid_value_sell = lot_size;
double last_traded_price_buy, last_traded_price_sell;
double lot_resetted = true;
datetime clear_time;                // time to clear info box from chart
double last_possible_buy, last_possible_sell;
bool first_buy, first_sell;

double daily_balance;
datetime last_account_check;
double daily_drawdown;



//+-----------------       original functions       -----------------+




//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   sInfo.Name(_Symbol);
   
   trade.SetExpertMagicNumber(Magic);
   
   last_traded_price_buy  = 0;
   last_traded_price_sell = 0;
   
   first_buy=true;
   first_sell=true;
   
   daily_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   draw_trade_box();
   
   //--- create panel
   if (MQLInfoInteger(MQL_TESTER))
   {
      Print("runing in tester");
      PANEL_H = 25;
      PANEL_W = 35;
   }
   create_panel();
   
   
   
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   clear_objects();
   app.Destroy(reason);
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   double 
         bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID),
         ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   static int total_bars = iBars(_Symbol, PERIOD_CURRENT);
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   
   
   //--- calculate open positions
   calculate_profit(2);
   if (enable_buy) calculate_profit(POSITION_TYPE_BUY);     //0
   if (enable_sell) calculate_profit(POSITION_TYPE_SELL);   //1
   
   //--- change start price
   
   int total = 0;
   for (int j=0; j<PositionsTotal(); j++){
      ulong tikt = PositionGetTicket(j);
      if (PositionSelectByTicket(tikt))
      {
         if (PositionGetInteger(POSITION_MAGIC) == Magic) total ++;
      }
   }   
   
   if (PositionsTotal() == 0 || total == 0)
   {  
      // reset lot size
      lot_resetted = true;
      old_lot_grid_value_buy  = lot_size;
      old_lot_grid_value_sell = lot_size;
   }
   
   if (total_bars != bars){
      //--- get number of open positions
      int buys, sells;
      double bl, sl;
      number_of_positions(buys , sells, bl, sl);
      
      //--- GRID
      if( enable_buy )
      {
         if ( check_buy_direction(ask) || first_buy )      grid_buy();
      }
      if( enable_sell )
      {
         if ( check_sell_direction(bid) || first_sell )   grid_sell();
      }
      
      
      total_bars = bars;
   }
  
   // check if a position was suddenly closed
   check_arrays();
   
   // update labels 
   update_labels_text();
   
   if (TimeCurrent()> clear_time && ObjectFind(0, BOX_NAME)>=0) clear_box();
   
   find_max_equity_drawdown();
}






//+-----------------        common functions        -----------------+




//+------------------------------------------------------------------+
//| calculate the price which equals the input hedge profit          |
//+------------------------------------------------------------------+
void calculate_profit (int type){
   string info="";
   int size = ArraySize(positions_data)/6;
   
   double current_total_profit = 0;
   string tikets;
   for (int j=0; j<size; j++){
      if (PositionSelectByTicket((ulong)positions_data[j][0])){
         int pos_type = (int)PositionGetInteger(POSITION_TYPE);
         
         if (type==pos_type || type==2)
         {
            double 
               p = PositionGetDouble(POSITION_PROFIT),
               s = PositionGetDouble(POSITION_SWAP),
               c = PositionGetDouble(POSITION_VOLUME)*6.6;
            
            if (profit_mtd == Profit)
               current_total_profit += (p);
            else if (profit_mtd == commission)
               current_total_profit += (p-c);
            else
               current_total_profit += (p-c-s);
               
            tikets += positions_data[j][0] + " ";
         }
      }
   }
   
   //--- choose profit criteria
   double profit_criteria = type==0? buy_profit :type==1 ? sell_profit :total_profit;
   if (current_total_profit > profit_criteria)
   {
      info += "positions <"+ tikets+ "> were closed with total profit of "+ (string) NormalizeDouble(current_total_profit,2)+" \n";
      clear_array(type);
   }
   
   if (info != "")
      create_info_box(info);
      
}


//+------------------------------------------------------------------+
//| stores grid position data in an array                            |
//+------------------------------------------------------------------+
void store_grid_data(string pos_number, string pos_type, double lot){
   int size = ArraySize(positions_data)/6;
   ArrayResize(positions_data, size+1);
   //--- calculate price level
   double price;
   if (pos_type == "buy")
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   positions_data[size][0] = pos_number;
   positions_data[size][1] = ( string )price;
   positions_data[size][2] = _Symbol;
   positions_data[size][3] = pos_type;
   positions_data[size][4] = (string)lot;
   positions_data[size][5] = TimeToString(TimeCurrent());
}



//+------------------------------------------------------------------+
//| clear the position_data array from ea-closed trades              |
//+------------------------------------------------------------------+
void clear_array(int type){
   for (int i=(ArraySize(positions_data)/6)-1; i>=0; i--){
      if( (type==2) || 
          (type==0 && positions_data[i][3]=="buy") || 
          (type==1 && positions_data[i][3]=="sell") )
      {
            trade.PositionClose((ulong)positions_data[i][0]);
            ArrayRemove(positions_data, i,1);
      }
   }
}


//+------------------------------------------------------------------+
//| remove trades that were closed unexpectedly                      |
//+------------------------------------------------------------------+
void check_arrays(){
   for (int i=ArraySize(positions_data)/6-1; i>=0; i--){
      if (!PositionSelectByTicket((ulong)positions_data[i][0]))
      {
         ArrayRemove(positions_data, i,1);
      }
   }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void number_of_positions(int&buys , int&sells, double& buys_lot, double& sells_lot){
   int size = ArraySize(positions_data)/6;
   
   buys = 0;
   buys_lot = 0;
   sells = 0;
   sells_lot = 0;
   
   for (int i=0; i<size; i++){
      if (positions_data[i][3] == "buy") 
      {
         buys ++;
         buys_lot += (double)positions_data[i][4];
      }
      if (positions_data[i][3] == "sell") 
      {
         sells ++;
         sells_lot += (double)positions_data[i][4];
      }
   }
   
   buys_lot = NormalizeDouble(buys_lot, 2);
   sells_lot = NormalizeDouble(sells_lot, 2);
}


//+------------------------------------------------------------------+
//| fix lot size digit to symbol favor                               |
//+------------------------------------------------------------------+
double fix_lot_size_digits(double lot){
   double 
      step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP),
      min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
      max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   int digit = ( int )MathAbs(log10(step));
   
   double result = NormalizeDouble(lot, digit);
   return MathMin(max, MathMax(min, result));
}







//+-----------------          buy functions          -----------------+




//+------------------------------------------------------------------+
//| opens a new buy position upon each tp in Grid                    |
//+------------------------------------------------------------------+
void grid_buy(){
   double 
      current        = SymbolInfoDouble(_Symbol, SYMBOL_ASK),
      buy_tp         = 0,
      new_lot_buy    = buy_lot_mtd == aggressive ? 
            old_lot_grid_value_buy * (1 + (buy_multiplier/100)) :
            old_lot_grid_value_buy + (lot_size*buy_multiplier/100);
   
   double buy_lot = lot_resetted||first_buy ? old_lot_grid_value_buy : new_lot_buy;
   
   if (lot_resetted) lot_resetted = false;
   
   if (trade.Buy(fix_lot_size_digits(buy_lot), _Symbol, 0, 0, buy_tp, user_comment))
   {
      store_grid_data((string)trade.ResultOrder(), "buy", buy_lot);
      old_lot_grid_value_buy = buy_lot;
      last_traded_price_buy = current;
      last_possible_buy = current;
      first_buy=false;
   }
}


//+------------------------------------------------------------------+
//| evaluate if movement matches the buy criteria                    |
//+------------------------------------------------------------------+
bool check_buy_direction(double price){
   int size = ArraySize(positions_data)/6;
   int buys = 0;
   int sells = 0;
   for (int i=0; i<size; i++){
      if (positions_data[i][3] == "buy") buys ++;
      if (positions_data[i][3] == "sell") sells ++;
   }
   
   if (last_traded_price_buy - price > buy_step*_Point*10)
   {
      Print("----------  BUY now based on last traded price which is ", last_traded_price_buy);
      return true;
   }
   
   if (buys==0) 
   {
      //--- change last possible buy price
      if (price - last_possible_buy > buy_step*_Point*10){
         last_possible_buy = price;
         Print("----------  changed last possible BUY");
      }
      if (last_possible_buy == 0 && last_traded_price_buy != 0){
         if (price - last_traded_price_buy > buy_step*_Point*10)
         {
            last_possible_buy = price;
            Print("----------  changed last possible BUY based on last trade price");
         }
      }
      
      //--- buy if price moves up
      if (last_possible_buy - price > buy_step*_Point*10  && last_possible_buy != 0)
      {
         Print("----------  BUY now based on moving up from a deep");
         return true;
      }
      
   }
 
   return false;
}







//+-----------------          sell functions         -----------------+




//+------------------------------------------------------------------+
//| opens a new sell position upon each tp in Grid                   |
//+------------------------------------------------------------------+
void grid_sell(){
   double 
      current        = SymbolInfoDouble(_Symbol, SYMBOL_BID),
      sell_tp        = 0,
      new_lot_sell   = sell_lot_mtd == aggressive ? 
            old_lot_grid_value_sell *(1 + (sell_multiplier/100)) :
            old_lot_grid_value_sell + (lot_size*sell_multiplier/100); 
   
   double sell_lot = lot_resetted||first_sell ? old_lot_grid_value_sell : new_lot_sell;
   if (lot_resetted) lot_resetted = false;
   
      if (trade.Sell(fix_lot_size_digits(sell_lot), _Symbol, 0, 0, sell_tp, user_comment))
      {
         store_grid_data((string)trade.ResultOrder(), "sell", sell_lot);
         old_lot_grid_value_sell = sell_lot;
         last_traded_price_sell = current;
         last_possible_sell = current;
         first_sell=false;
      }
}


//+------------------------------------------------------------------+
//| evaluate if movement matches the sell criteria                   |
//+------------------------------------------------------------------+
bool check_sell_direction(double price){
   int size = ArraySize(positions_data)/6;
   int sells = 0;
   int buys = 0;
   for (int i=0; i<size; i++){
      if (positions_data[i][3] == "sell") sells ++;
      if (positions_data[i][3] == "buy") buys ++;
   }
   
   if (price - last_traded_price_sell > sell_step*_Point*10)
   {
      Print("----------  sell now based on last traded price which is ", last_traded_price_sell);
      return true;
   }
   
   if (sells==0) 
   {
      //--- change last possible sell price
      if (last_possible_sell - price > sell_step*_Point*10){
         last_possible_sell = price;
         Print("----------  changed last possible sell");
      }
      if (last_possible_sell == 0 && last_traded_price_sell != 0){
         if (last_traded_price_sell - price > sell_step*_Point*10)
         {
            last_possible_sell = price;
            Print("----------  changed last possible sell based on last trade price");
         }
      }
      
      //--- sell if price moves up
      if (price - last_possible_sell > sell_step*_Point*10  && last_possible_sell != 0)
      {
         Print("----------  sell now based on moving up from a deep");
         return true;
      }
      
   }
 
   return false;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void find_max_equity_drawdown(){
   double total_equity = 0;
   for(int i=0;i<ArraySize(positions_data)/6;i++){
      if (PositionSelectByTicket((long)positions_data[i][0]))
      {
         total_equity += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   if (total_equity < daily_drawdown) daily_drawdown = total_equity;
}






//+-----------------         chart functions         -----------------+




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long& lparam,const double& dparam,const string& sparam){
   
   app.ChartEvent(id,lparam, dparam, sparam);
   
   if (id==CHARTEVENT_OBJECT_CLICK)
   {
      if (sparam == submit.Name())
      {
         Print("submit clicked");
         enable_buy = buy_checkbox.Checked();
         buy_step = (int)buy_step_inp_edit.Text();
         buy_multiplier = (double)buy_multiplier_inp_edit.Text();
         buy_profit = (int)buy_profit_inp_edit.Text();
         
         enable_sell = sell_checkbox.Checked();
         sell_step = (int)sell_step_inp_edit.Text();
         sell_multiplier = (double)sell_multiplier_inp_edit.Text();
         sell_profit = (int)sell_profit_inp_edit.Text();
         
         total_profit = (int)total_profit_inp_edit.Text();
         lot_size = (double)lot_size_edit.Text();
      }
   }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void create_panel(){
   app.Create(0, "app", 0, 25, 50, PANEL_W+40, (int)PANEL_H*1.8);
   
   buy_checkbox.Create(0,"bc", 0, PANEL_W/8, 5, 3*PANEL_W/8, PANEL_H/5);
   buy_checkbox.Text("Enable Buy ?");
   app.Add(buy_checkbox);
   
   buy_step_inp_label.Create(0, "bsil", 0, 0, PANEL_H/5, PANEL_W/4, 2*PANEL_H/5);
   buy_step_inp_label.Text("Buy Step");
   app.Add(buy_step_inp_label);
   
   buy_step_inp_edit.Create(0, "bsie", 0, PANEL_W/4, PANEL_H/5, PANEL_W/2, 2*PANEL_H/5);
   buy_step_inp_edit.Text((string)buy_step);
   app.Add(buy_step_inp_edit);
   
   
   buy_multiplier_inp_label.Create(0, "bmil", 0, 0, 2*PANEL_H/5, PANEL_W/4, 3*PANEL_H/5);
   buy_multiplier_inp_label.Text("Buy Lot Increase");
   app.Add(buy_multiplier_inp_label);
   
   buy_multiplier_inp_edit.Create(0, "bmie", 0, PANEL_W/4, 2*PANEL_H/5, PANEL_W/2, 3*PANEL_H/5);
   buy_multiplier_inp_edit.Text((string)buy_multiplier);
   app.Add(buy_multiplier_inp_edit);
   
   
   buy_profit_inp_label.Create(0, "bpil", 0, 0, 3*PANEL_H/5, PANEL_W/4, 4*PANEL_H/5);
   buy_profit_inp_label.Text("Profit of Buy");
   app.Add(buy_profit_inp_label);
   
   buy_profit_inp_edit.Create(0, "bpie", 0, PANEL_W/4, 3*PANEL_H/5, PANEL_W/2, 4*PANEL_H/5);
   buy_profit_inp_edit.Text((string)buy_profit);
   app.Add(buy_profit_inp_edit);
   

   sell_checkbox.Create(0,"sc", 0, 5*PANEL_W/8, 5, 7*PANEL_W/8, PANEL_H/5);
   sell_checkbox.Text("Enable Sell ?");
   app.Add(sell_checkbox);
   
   sell_step_inp_label.Create(0, "ssil", 0, 2*PANEL_W/4, PANEL_H/5, 3*PANEL_W/4, 2*PANEL_H/5);
   sell_step_inp_label.Text("Sell Step");
   app.Add(sell_step_inp_label);
   
   sell_step_inp_edit.Create(0, "ssie", 0, 3*PANEL_W/4, PANEL_H/5, PANEL_W, 2*PANEL_H/5);
   sell_step_inp_edit.Text((string)sell_step);
   app.Add(sell_step_inp_edit);
   
   
   sell_multiplier_inp_label.Create(0, "smil", 0, 2*PANEL_W/4, 2*PANEL_H/5, 3*PANEL_W/4, 3*PANEL_H/5);
   sell_multiplier_inp_label.Text("sell Lot Increase");
   app.Add(sell_multiplier_inp_label);
   
   sell_multiplier_inp_edit.Create(0, "smie", 0, 3*PANEL_W/4, 2*PANEL_H/5, PANEL_W, 3*PANEL_H/5);
   sell_multiplier_inp_edit.Text((string)sell_multiplier);
   app.Add(sell_multiplier_inp_edit);
   
   
   sell_profit_inp_label.Create(0, "spil", 0, 2*PANEL_W/4, 3*PANEL_H/5, 3*PANEL_W/4, 4*PANEL_H/5);
   sell_profit_inp_label.Text("Profit of Sell");
   app.Add(sell_profit_inp_label);
   
   sell_profit_inp_edit.Create(0, "spie", 0, 3*PANEL_W/4, 3*PANEL_H/5, PANEL_W, 4*PANEL_H/5);
   sell_profit_inp_edit.Text((string)sell_profit);
   app.Add(sell_profit_inp_edit);
   
   
   
   total_profit_inp_label.Create(0, "tpil", 0, 0, 4*PANEL_H/5+10, PANEL_W/4, PANEL_H+10);
   total_profit_inp_label.Text("Total Profit");
   app.Add(total_profit_inp_label);
   
   total_profit_inp_edit.Create(0, "tpie", 0, PANEL_W/4, 4*PANEL_H/5+10, 2*PANEL_W/4, PANEL_H+10);
   total_profit_inp_edit.Text((string)total_profit);
   app.Add(total_profit_inp_edit);
   
   
   lot_size_label.Create(0, "lsl", 0, PANEL_W/2, 4*PANEL_H/5+10, 3*PANEL_W/4, PANEL_H+10);
   lot_size_label.Text("Lot Size");
   app.Add(lot_size_label);
   
   lot_size_edit.Create(0, "lse", 0, 3*PANEL_W/4, 4*PANEL_H/5+10, PANEL_W, PANEL_H+10);
   lot_size_edit.Text((string)lot_size);
   app.Add(lot_size_edit);
   
   
   submit.Create(0, "submit btn", 0, PANEL_W/4, PANEL_H+20, 3*PANEL_W/4, 6*PANEL_H/5+20);
   submit.Text("Submit");
   app.Add(submit);
}







//+-----------------          draw functions         -----------------+



//+------------------------------------------------------------------+
//| create a ui box for user to see closed positions                 |
//+------------------------------------------------------------------+
void create_info_box(string text){
   int len = StringLen(text);
   
   if(ObjectFind(0, BOX_NAME) <= -1)
   {
      ObjectCreate(0, BOX_NAME, OBJ_RECTANGLE_LABEL, 0, 0,0);
      ObjectSetInteger(0, BOX_NAME, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, BOX_NAME, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, BOX_NAME, OBJPROP_YDISTANCE, 36);
      ObjectSetInteger(0, BOX_NAME, OBJPROP_XSIZE, 50+len*8);
      ObjectSetInteger(0, BOX_NAME, OBJPROP_YSIZE, 32);
      ObjectSetInteger(0, BOX_NAME, OBJPROP_BGCOLOR, box_clr);
      ObjectSetInteger(0, BOX_NAME, OBJPROP_COLOR, box_clr);
   }
   else {
      ObjectSetInteger(0, BOX_NAME, OBJPROP_XSIZE, 50+len*8);
   }
   if (ObjectFind(0, TEXT_NAME) <= -1)
   {
      ObjectCreate(0, TEXT_NAME, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, TEXT_NAME, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, TEXT_NAME, OBJPROP_XDISTANCE, 30);
      ObjectSetInteger(0, TEXT_NAME, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(0, TEXT_NAME, OBJPROP_COLOR, text_clr);
   }
   
   ObjectSetString(0, TEXT_NAME, OBJPROP_TEXT, text);
   
   clear_time = TimeCurrent()+PeriodSeconds(PERIOD_CURRENT)*box_time;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_trade_box(){
   if(ObjectFind(0, TRADE_BOX) <= -1)
   {
      ObjectCreate(0, TRADE_BOX, OBJ_RECTANGLE_LABEL, 0, 0,0);
      ObjectSetInteger(0, TRADE_BOX, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, TRADE_BOX, OBJPROP_XDISTANCE, 270);
      ObjectSetInteger(0, TRADE_BOX, OBJPROP_YDISTANCE, 100);
      ObjectSetInteger(0, TRADE_BOX, OBJPROP_XSIZE, 250);
      ObjectSetInteger(0, TRADE_BOX, OBJPROP_YSIZE, 96);
      ObjectSetInteger(0, TRADE_BOX, OBJPROP_BGCOLOR, box_clr);
      ObjectSetInteger(0, TRADE_BOX, OBJPROP_COLOR, box_clr);
   }
   if(ObjectFind(0, BUY_TEXT) <= -1)
   {
      ObjectCreate(0, BUY_TEXT, OBJ_LABEL, 0, 0,0);
      ObjectSetInteger(0, BUY_TEXT, OBJPROP_COLOR, text_clr);
      ObjectSetInteger(0, BUY_TEXT, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, BUY_TEXT, OBJPROP_XDISTANCE, 250);
      ObjectSetInteger(0, BUY_TEXT, OBJPROP_YDISTANCE, 95);
      ObjectSetString(0, BUY_TEXT, OBJPROP_TEXT, "");
   }
   if(ObjectFind(0, SELL_TEXT) <= -1)
   {
      ObjectCreate(0, SELL_TEXT, OBJ_LABEL, 0, 0,0);
      ObjectSetInteger(0, SELL_TEXT, OBJPROP_COLOR, text_clr);
      ObjectSetInteger(0, SELL_TEXT, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, SELL_TEXT, OBJPROP_XDISTANCE, 250);
      ObjectSetInteger(0, SELL_TEXT, OBJPROP_YDISTANCE, 70);
      ObjectSetString(0, SELL_TEXT, OBJPROP_TEXT, "");
   }
   if(ObjectFind(0, EQUITY_TEXT) <= -1)
   {
      ObjectCreate(0, EQUITY_TEXT, OBJ_LABEL, 0, 0,0);
      ObjectSetInteger(0, EQUITY_TEXT, OBJPROP_COLOR, text_clr);
      ObjectSetInteger(0, EQUITY_TEXT, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, EQUITY_TEXT, OBJPROP_XDISTANCE, 250);
      ObjectSetInteger(0, EQUITY_TEXT, OBJPROP_YDISTANCE, 45);
      ObjectSetString(0, EQUITY_TEXT, OBJPROP_TEXT, "-");
   }
   if(ObjectFind(0, BALANCE_TEXT) <= -1)
   {
      ObjectCreate(0, BALANCE_TEXT, OBJ_LABEL, 0, 0,0);
      ObjectSetInteger(0, BALANCE_TEXT, OBJPROP_COLOR, text_clr);
      ObjectSetInteger(0, BALANCE_TEXT, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, BALANCE_TEXT, OBJPROP_XDISTANCE, 250);
      ObjectSetInteger(0, BALANCE_TEXT, OBJPROP_YDISTANCE, 20);
      ObjectSetString(0, BALANCE_TEXT, OBJPROP_TEXT, "-");
   }
   
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void update_labels_text(){

   if(ObjectFind(0, TRADE_BOX) <= -1)
   {
      draw_trade_box();
   }
   
   
   int buys, sells;
   double buy_l, sell_l;
   
   number_of_positions(buys, sells, buy_l, sell_l);
   
   string buy_text = "";
   StringConcatenate(buy_text, "total buys : ", (string)buys, "   lot : ", (string)buy_l);
   ObjectSetString(0, BUY_TEXT, OBJPROP_TEXT, buy_text);
   
   string sell_text = "";
   StringConcatenate(sell_text, "total sells : ", (string)sells, "   lot : ", (string)sell_l);
   ObjectSetString(0, SELL_TEXT, OBJPROP_TEXT, sell_text);
   
   string equity_text = "";
   StringConcatenate(equity_text, "equity drawdown : ", (string)NormalizeDouble(daily_drawdown, 2));
   ObjectSetString(0, EQUITY_TEXT, OBJPROP_TEXT, equity_text);
   
   if (TimeCurrent() > StringToTime(balance_time) && last_account_check < StringToTime(balance_time)){
      string account_text = "";
      double today_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      StringConcatenate(account_text, "yesterday's profit : ", (string)NormalizeDouble(today_balance-daily_balance, 2));
      ObjectSetString(0, BALANCE_TEXT, OBJPROP_TEXT, account_text);
      
      daily_balance = today_balance;
      daily_drawdown=0;
      last_account_check = TimeCurrent();
   }
}


//+------------------------------------------------------------------+
//| remove all objects drawn                                         |
//+------------------------------------------------------------------+
void clear_objects(){
   ObjectDelete(0, BOX_NAME);
   ObjectDelete(0, TEXT_NAME);
   ObjectDelete(0, TRADE_BOX);
   ObjectDelete(0, BUY_TEXT);
   ObjectDelete(0, SELL_TEXT);
   ObjectDelete(0, BALANCE_TEXT);
   ObjectDelete(0, EQUITY_TEXT);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void clear_box(){
   ObjectDelete(0, BOX_NAME);
   ObjectDelete(0, TEXT_NAME);
}