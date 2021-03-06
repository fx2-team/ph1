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
extern double SLpipsRate = 0.8;   // 損切り値pips
extern double TPpipsRate = 1.0;   // 利食い値pips

// エントリー関数
extern int BBPeriod = 20;  // ボリンジャーバンドの期間
extern double BBDev = 2.5;      // 標準偏差の倍率
extern double WaitPeriod = 10;      // 標準偏差の倍率

// フィルター関数
extern string StartTime = "19:00";   // 開始時刻
extern string EndTime = "23:59";    // 終了時刻


void MyOrderModify(int magic)
{
   double bbU1=0,bbL1=0;   
   double sl=0, tp=0;   
   
   for(int i=0; i <=OrdersTotal(); i++){ 
      if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MAGIC) continue;

      bbU1 = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_UPPER, 1);
      bbL1 = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_LOWER, 1);

      double lows = Bid;
      double highs = Bid;
   
      if(OrderType()==0) 
      {
        tp=bbL1+(bbU1-bbL1)*TPpipsRate;    
        sl=bbU1-(bbU1-bbL1)*SLpipsRate;            
        if (sl < OrderStopLoss()) sl=OrderStopLoss();
      }
      else if(OrderType()==1) 
      {
        tp=bbU1-(bbU1-bbL1)*TPpipsRate;       
        sl=bbL1+(bbU1-bbL1)*SLpipsRate;    
        if (sl > OrderStopLoss()) sl=OrderStopLoss();
       }
      
      OrderModify(OrderTicket(), 0, sl, tp, 0);
      break;
      
   }
 
}


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



// オーダー送信関数（ボリンジャー幅から計算）
bool MyOrderSendSL(int type, double lots, double price, int slippage, int slpips, int tppips, string comment, int magic)
{

   int mult=1;
   if(Digits == 3 || Digits == 5) mult=10;
   slippage *= mult;

   // ボリンジャーバンドの幅で利食いを計算
   double bbU1 = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_UPPER, 1);
   double bbL1 = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_LOWER, 1);

   double lows = price;
   double highs = price;
   
   double sl=0, tp=0;

   if(type==OP_BUY) 
   {
      tp=bbL1+(bbU1-bbL1)*TPpipsRate;    
      sl=bbU1-(bbU1-bbL1)*SLpipsRate;    
   }
   else
   {
      tp=bbU1-(bbU1-bbL1)*TPpipsRate;       
      sl=bbL1+(bbU1-bbL1)*SLpipsRate;    
   }
   

   return(MyOrderSend(type, lots, price, slippage, sl, tp, comment, magic));
}

// スタート関数
int start()
{
   // 決済変更
   MyOrderModify(MAGIC);

   // エントリーシグナル
   int sig_entry = EntrySignal(MAGIC);

   // エントリーのフィルター1
   sig_entry = FilterSignal(sig_entry);

   // 買い注文
   if(sig_entry > 0)
   {
      //MyOrderClose(Slippage, MAGIC);
     MyOrderSendSL(OP_BUY, Lots, Ask, Slippage, 0, 0, COMMENT, MAGIC);
   }
   // 売り注文
   if(sig_entry < 0)
   {
      //MyOrderClose(Slippage, MAGIC);
      MyOrderSendSL(OP_SELL, Lots, Bid, Slippage, 0, 0, COMMENT, MAGIC);
   }

   return(0);
}

