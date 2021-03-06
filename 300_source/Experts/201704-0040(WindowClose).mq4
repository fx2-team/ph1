//+------------------------------------------------------------------+
//|                                                     BBCross1.mq4 |
//|                                   Copyright (c) 2009, Toyolab FX |
//|                                         http://forex.toyolab.com |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2009, Toyolab FX"
#property link      "http://forex.toyolab.com"

// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   2017042601
#define COMMENT "WindowClose1"

// 外部パラメータ
extern double Lots = 0.1;
extern int Slippage = 3;
extern double SLpipsRate = 1;   // 損切り値幅(%)
extern double TPpipsRate = 1;   // 利食い値幅(%)

extern double MINpips = 10;    // 発動最小Pips
extern double MAXpips = 90;   // 発動最大Pips


// フィルター関数
extern string StartTime = "00:00";   // 開始時刻
extern string EndTime = "03:00";    // 終了時刻

int EntrySignal(int magic)
{

   double pips = 0;
   int ret = 0;
   int mult=1;
   if(Digits == 3 || Digits == 5) mult=10;

   if (Open[1] == Close[2])  return(ret);

   else if (Open[1]>Close[2]) 
   {
    pips = (Open[1] - Close[2])/Point/mult;
      // 売りシグナル
    if(pips >= MINpips && pips <= MAXpips) 
    {
         ret = -1;
         Print("SELL_Close=",Close[2]);
         Print("SELL_Open=",Open[1]);
    }
   }

   else if (Open[1]<Close[2]) 
   {
      pips = (Close[2] - Open[1])/Point/mult;
         
      // 買いシグナル
      if(pips >= MINpips && pips <= MAXpips) 
      {
         ret = 1;
         Print("BUY_Close=",Close[2]);
         Print("BUY_Open=",Open[1]);
      }
   }
   return(ret);
}

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

int FilterSignal2(int signal)
{
   int date = DayOfWeek();
   int ret = 0;
   
   if(date != 1)
   {
      ret = 0;
   }
   else
   {
      ret = signal;
   }

   return(ret);
}


// オーダー送信関数（損切り・利食いを幅で調整）
bool MyOrderSendSL(int type, double lots, double price, int slippage, int slpips, int tppips, string comment, int magic)
{
   //固定Pipsで計算
   /*
   int mult=1;
   if(Digits == 3 || Digits == 5) mult=10;
   slippage *= mult;

   if(type==OP_SELL || type==OP_SELLLIMIT || type==OP_SELLSTOP) mult *= -1;

   double sl=0, tp=0;
   if(slpips > 0) sl = price-slpips*Point*mult;
   if(tppips > 0) tp = price+tppips*Point*mult;
   */

   double sl=0, tp=0;

   if(type==OP_BUY) 
   {
      tp=Open[1]+(Close[2]-Open[1])*TPpipsRate;    
      sl=Open[1]-(Close[2]-Open[1])*SLpipsRate;  
   }
   else
   {
      tp=Open[1]-(Open[1]-Close[2])*TPpipsRate;    
      sl=Open[1]+(Open[1]-Close[2])*SLpipsRate;  
   }

   return(MyOrderSend(type, lots, price, slippage, sl, tp, comment, magic));
}

// スタート関数
int start()
{
   // エントリーシグナル
   int sig_entry = EntrySignal(MAGIC);

   // エントリーのフィルター
   sig_entry = FilterSignal(sig_entry);
   sig_entry = FilterSignal2(sig_entry);

   // 買い注文
   if(sig_entry > 0)
   {
      MyOrderSendSL(OP_BUY, Lots, Ask, Slippage, 0, 0, COMMENT, MAGIC);
   }
   // 売り注文
   if(sig_entry < 0)
   {
      MyOrderSendSL(OP_SELL, Lots, Bid, Slippage, 0, 0, COMMENT, MAGIC);
   }

   return(0);
}

