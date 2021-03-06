// ボリンジャー3分戻り待ち
#property copyright "Copyright (c) 2017, TeamFX2"

// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   2017043001
#define COMMENT "BBCross_Trend"

// 外部パラメータ
extern double Lots = 0.1;
extern int Slippage = 3;
extern double SLpips = 5;   // 損切り値pips
extern double TPpips = 5;   // 利食い値pips(未使用)
extern double SLpipsRate = 0.7;   // 損切り値幅(%) (未使用)
extern double TPpipsRate = 0.7;   // 利食い値幅(%)
extern int ExpBars = 10; //負けの後に注文しないバーの経過本数

// エントリー関数
extern int BBPeriod = 20;  // ボリンジャーバンドの期間
extern double BBDev = 3;      // 標準偏差の倍率

// フィルター関数
extern string StartTime = "19:00";   // 開始時刻
extern string EndTime = "23:59";    // 終了時刻

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
         if(Close[3] > bbL1[3]) 
         {
            if(Ask < (Low[4]+High[3])/2)  ret = 1;
         }
      }

      else if(Low[4] >= bbL1[4] && Low[3] < bbL1[3]) 
      {
       if(Close[2] > bbL1[2])
         {
            if(Ask < (Low[3]+High[2])/2)  ret = 1;
         }
      }

      else if(Low[3] >= bbL1[3] && Low[2] < bbL1[2]) 
      {
         if(Close[1] > bbL1[1])
         {
            if(Ask < (Low[2]+High[1])/2)  ret = 1;
         }
      }

   // 売りシグナル
      if(High[5] <= bbU1[5] && High[4] > bbU1[4]) 
      {
         if(Close[3] < bbU1[3]) 
         {
            if(Bid > (High[4]+Low[3])/2)  ret = -1;
         }
      }

      else if(High[4] <= bbU1[4] && High[3] > bbU1[3]) 
      {
         if(Close[2] < bbU1[2]) 
         {
            if(Bid > (High[3]+Low[2])/2)  ret = -1;
         }
      }

      else if(High[3] <= bbU1[3] && High[2] > bbU1[2]) 
      {
         if(Close[1] < bbU1[1]) 
         {
            if(Bid > (High[2]+Low[1])/2)  ret = -1;
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


// トレンドと逆の注文は無視する
extern int SMAPeriod = 200;   // 移動平均の期間
int FilterSignal2(int signal)
{
   double sma1 = iMA(NULL, 0, SMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);

   int ret = 0;
   if(signal > 0 && Close[1] > sma1) ret = signal;
   if(signal < 0 && Close[1] < sma1) ret = signal;

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
      sl=lows-slpips*Point*mult;    
//      Print("slpips=",slpips);
//      Print("lows=",lows);
//      Print("sl=",sl);
   }
   else
   {
      tp=bbU1-(bbU1-bbL1)*TPpipsRate;       
      sl=highs+slpips*Point*mult; ;
   }
   

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
   sig_entry = FilterSignal2(sig_entry);

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

