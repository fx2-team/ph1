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
extern double SLpips = 5;   // 損切り値pips
//extern double TPpips = 5;   // 利食い値pips(未使用)
//extern double SLpipsRate = 0.7;   // 損切り値幅(%) (未使用)
extern double TPpipsRate = 1.0;   // 利食い値幅(%)

// エントリー関数
extern int BBPeriod = 20;  // ボリンジャーバンドの期間
extern double BBDev = 3;      // 標準偏差の倍率

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
        sl=OrderStopLoss();            
      }
      else if(OrderType()==1) 
      {
        tp=bbU1-(bbU1-bbL1)*TPpipsRate;       
        sl=OrderStopLoss();            
       }
      
      OrderModify(OrderTicket(), 0, sl, tp, 0);
      break;
      
   }
 
}


int EntrySignal(int magic)
{
   // オープンポジションの計算
   double pos = MyCurrentOrders(MY_OPENPOS, magic);
   double bbU1[10];
   double bbL1[10];

   // ボリンジャーバンドの計算
   for(int i=1; i<=9; i++) {
    bbU1[i] = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_UPPER, i);
    bbL1[i] = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_LOWER, i);
   }

   //ボリンジャーを超えた後の戻り方でシグナルを発生
   int ret = 0;

   if(pos == 0)   //保有ポジションがないかの判定
   {
      // 買いシグナル
   
      if(Low[5] >= bbL1[5] && Low[4] < bbL1[4]) 
      {
         if(Close[3] > bbL1[3] && Close[3]>Open[3]) 
         {
            if(Ask < (Low[4]+High[3])/2)  ret = 1;
         }
      }

      else if(Low[4] >= bbL1[4] && Low[3] < bbL1[3]) 
      {
       if(Close[2] > bbL1[2] && Close[2]>Open[2])
         {
            if(Ask < (Low[3]+High[2])/2)  ret = 1;
         }
      }

      else if(Low[3] >= bbL1[3] && Low[2] < bbL1[2]) 
      {
         if(Close[1] > bbL1[1]  && Close[1]>Open[1])
         {
            if(Ask < (Low[2]+High[1])/2)  ret = 1;
         }
      }

   // 売りシグナル
      if(High[5] <= bbU1[5] && High[4] > bbU1[4]) 
      {
         if(Close[3] < bbU1[3] && Close[3]<Open[3]) 
         {
            if(Bid > (High[4]+Low[3])/2)  ret = -1;
         }
      }

      else if(High[4] <= bbU1[4] && High[3] > bbU1[3]) 
      {
         if(Close[2] < bbU1[2 && Close[2]<Open[2]]) 
         {
            if(Bid > (High[3]+Low[2])/2)  ret = -1;
         }
      }

      else if(High[3] <= bbU1[3] && High[2] > bbU1[2]) 
      {
         if(Close[1] < bbU1[1] && Close[1]<Open[1]) 
         {
            if(Bid > (High[2]+Low[1])/2)  ret = -1;
         }
      }
   }

   return(ret);
}


//時間でフィルター
int FilterSignal(int signal)
{
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


//ボリンジャーの広がり
extern double BBFilterRate = 1.3; 
extern int ExpBars1 = 20; 
int FilterSignal2(int signal)
{
   int ret = signal;   
   double bbU1[21];
   double bbU1_Ave=0;   
   double bbL1[21];
   double bbL1_Ave=0;   
   double rate=0;   
   
   for(int i=1; i<=ExpBars1; i++) {
    bbU1[i] = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_UPPER, i);
    bbU1_Ave = bbU1_Ave+bbU1[i];
    bbL1[i] = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_LOWER, i);
    bbL1_Ave = bbL1_Ave+bbL1[i];
   }

   bbU1_Ave=bbU1_Ave/ExpBars1;
   bbL1_Ave=bbL1_Ave/ExpBars1;

   rate=(bbU1[1]-bbL1[1])/(bbU1_Ave-bbL1_Ave);
   
   if(BBFilterRate < rate) {
      ret=0;
   }

   return(ret);
}

//一方方向に動いているときは逆注文をしない
extern int ExpBars2 = 30; 
extern double ExpRate = 1.0; 
int FilterSignal3(int signal)
{
   int ret = signal;   
   int down = 0;
   int up = 0;
   double bbM1[99];
   
   for(int i=1; i<=ExpBars2; i++) {
      bbM1[i] = iBands(NULL, 0, BBPeriod, BBDev, 0, PRICE_CLOSE, MODE_MAIN , i);
      if (bbM1[i] > High[i]) down=down+1;
      if (bbM1[i] < Low[i]) up=up+1;
   }

   if (up>=ExpBars2*ExpRate) {
      if (ret == -1) {
         ret=0;
      }
   }
   
   if (down>=ExpBars2*ExpRate) {
      if (ret == 1) {
         ret=0;
      }
   }
 
   return(ret);
}


// オーダー送信関数（損切り・利食いをボリンジャーの幅で調整）
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
   
   for(int i=1; i<=4; i++) {
    if(lows > Low[i]) lows = Low[i];
    if(highs < High[i]) highs = High[i];
   }

   double sl=0, tp=0;

   if(type==OP_BUY) 
   {
      tp=bbL1+(bbU1-bbL1)*TPpipsRate; 
         
      sl=lows-SLpips*Point*mult;    
      if(sl < price-10*Point*mult) sl=price-10*Point*mult;      
   }
   else
   {
      tp=bbU1-(bbU1-bbL1)*TPpipsRate;       

      sl=highs+SLpips*Point*mult; ;
      if(sl > price+10*Point*mult) sl=price+10*Point*mult;      
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
   if (sig_entry>0 || sig_entry<0)  sig_entry = FilterSignal(sig_entry);

   // エントリーのフィルター2
   if (sig_entry>0 || sig_entry<0)  sig_entry = FilterSignal2(sig_entry);

   // エントリーのフィルター3
   if (sig_entry>0 || sig_entry<0)  sig_entry = FilterSignal3(sig_entry);

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

