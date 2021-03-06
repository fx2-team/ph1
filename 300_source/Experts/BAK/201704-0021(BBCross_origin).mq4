// ボリンジャー3分戻り待ち
#property copyright "Copyright (c) 2017, TeamFX2"

// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   2017042601
#define COMMENT "BBCross_Origin"

// 外部パラメータ
extern double Lots = 0.1;
extern int Slippage = 3;
extern double SLpips = 9;   // 損切り値pips
extern double TPpips = 6;   // 利食い値pips

// エントリー関数
extern int BBPeriod = 20;  // ボリンジャーバンドの期間
extern double BBDev = 2.5;      // 標準偏差の倍率
extern double WaitPeriod = 10;      // 標準偏差の倍率

// フィルター関数
extern string StartTime = "19:00";   // 開始時刻
extern string EndTime = "23:59";    // 終了時刻

int EntrySignal(int magic)
{
   // オープンポジションの計算
   double pos = MyCurrentOrders(MY_OPENPOS, magic);
   double bbU1[11];
   double bbL1[11];

   // ボリンジャーバンドの計算
   for(int i=1; i<=10; i++) {
      bbU1[i] = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_UPPER, i);
      bbL1[i] = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_LOWER, i);
   }

   //ボリンジャーを超えてミドルまで戻りで注文
   int ret = 0;

   if(pos == 0)   //保有ポジションがないかの判定
   {
      // 買いシグナル
      for(i=2; i<=10; i++) {   
         if(Low[i] >= bbL1[i] && Low[i-1] < bbL1[i-1]) {
            if(Ask>=(bbL1[1]+bbU1[1])/2 && High[1]<(bbL1[1]+bbU1[1])/2)  ret = 1;
         }
      }

      // 売りシグナル
      for(i=2; i<=10; i++) {   
         if(High[i] <= bbU1[i] && High[i-1] > bbU1[i-1]) {
            if(Bid<=(bbL1[1]+bbU1[1])/2 && Low[1]>(bbL1[1]+bbU1[1])/2)  ret = -1;
         }
      }
   }

   return(ret);
}


int FilterSignal(int signal)
{
   //時間でフィルター
   string sdate = TimeToStr(TimeCurrent(), TIME_DATE);
   datetime start_time = StrToTime(sdate+" "+StartTime);
   datetime end_time = StrToTime(sdate+" "+EndTime);

   int ret = 0;
   if(start_time <= end_time)
   {
      if(TimeCurrent() >= start_time && TimeCurrent() < end_time) ret = signal;
      else ret = 0;
   }
   else
   {
      if(TimeCurrent() >= end_time && TimeCurrent() < start_time) ret = 0;
      else ret = signal;
   }

   return(ret);
}


int FilterSignal2(int signal)
{
   datetime closetime = 0;
   double profits=0;
   int ordertype = 10;
   int ret = signal;
   int traded_bar = 0;
   
   
   
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--){ 
      if(OrderSelect(i, SELECT_BY_POS,MODE_HISTORY) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MAGIC) continue;

      profits = OrderProfit();   
      closetime = OrderCloseTime();
      ordertype = OrderType();

      break;
      
   }

//直近で負けた場合には一定時間トレードしない
/*
   if(profits < 0) {
      if(closetime > 0) {
         traded_bar = iBarShift(NULL, 0, closetime, false);
      }
      if(traded_bar <= ExpBars) ret = 0;
   }
*/ 

//直近で負けた場合には逆の方向しかトレードしない
   if(profits < 0) {
      if(ordertype == 0 && ret > 0) {
         ret=0;
      }
      else if(ordertype == 1 && ret < 0) {
         ret=0;
      }
   }
 
   return(ret);
}

// オーダー送信関数（固定Pips）
bool MyOrderSendSL(int type, double lots, double price, int slippage, int slpips, int tppips, string comment, int magic)
{

   int mult=1;
   if(Digits == 3 || Digits == 5) mult=10;
   slippage *= mult;

   if(type==OP_SELL || type==OP_SELLLIMIT || type==OP_SELLSTOP) mult *= -1;

   double sl=0, tp=0;
   if(slpips > 0) sl = price-slpips*Point*mult;
   if(tppips > 0) tp = price+tppips*Point*mult;
   

   return(MyOrderSend(type, lots, price, slippage, sl, tp, comment, magic));
}

// スタート関数
int start()
{
   // エントリーシグナル
   int sig_entry = EntrySignal(MAGIC);

   // エントリーのフィルター1
   sig_entry = FilterSignal(sig_entry);

   // エントリーのフィルター2
//   sig_entry = FilterSignal2(sig_entry);

   // 買い注文
   if(sig_entry > 0)
   {
      //MyOrderClose(Slippage, MAGIC);
      MyOrderSendSL(OP_BUY, Lots, Ask, Slippage, SLpips, TPpips, COMMENT, MAGIC);
   }
   // 売り注文
   if(sig_entry < 0)
   {
      //MyOrderClose(Slippage, MAGIC);
      MyOrderSendSL(OP_SELL, Lots, Bid, Slippage, SLpips, TPpips, COMMENT, MAGIC);
   }

   return(0);
}

