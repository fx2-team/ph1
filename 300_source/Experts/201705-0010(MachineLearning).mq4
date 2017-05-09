//+------------------------------------------------------------------+
//|                                                  read_signal.mq4 |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//本書ライブラリ
#define POSITIONS 40
#include "LibEA4.mqh"

#property copyright "Copyright 2017, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| グローバル変数定義                                            |
//+------------------------------------------------------------------+
string last_timestamp = ""; //Tick毎ではなく1分足がFixしたタイミングだけ処理するために、直近実行した時刻をyyyy.MM.dd HH:mm形式で分単位
long last_timestamp_sec[] = {0,0}; //buy, sell それぞれの直近の売買時刻。0番目の要素がsell, 1番目の要素がbuy

int dts_long[100000]; // 買いシグナル点灯時刻の履歴
double probs_long[100000]; //買いシグナルの値
int dts_short[100000];  // 売りシグナル点灯時刻の履歴
double probs_short[100000];　//売りシグナルの値

int PREV_POS[] = {0,0}; // バックテスト時の性能をあげるため、前回読み込みシグナル情報配列のindex

int pos_size = 0; //ポジションを識別するためのindex

long pos_timestamp[POSITIONS]; //i番目のポジションをとった時刻

double init_balance = 0.0; //初期残高（複利を効かせる場合のみ利用）


//+------------------------------------------------------------------+
//| 初期化処理（バックテスト向けにシグナル情報を読み込み）                                      |
//+------------------------------------------------------------------+
void OnInit(){
  Print("start");
  cache_signal("mySignal.short.csv", dts_short, probs_short); //Pythonで出力した売りシグナルを読み込み
  cache_signal("mySignal.csv",dts_long, probs_long);//Pythonで出力した買いシグナルを読み込み
  init_balance = AccountBalance(); //初期残高を格納
}


//+------------------------------------------------------------------+
//| ロジックのメイン処理                                           |
//+------------------------------------------------------------------+
void OnTick()
 {      
   if(last_timestamp != TimeToStr(Time[1], TIME_DATE|TIME_MINUTES)){ //1分足が確定した場合
 
      //既存ポジションのクローズ判断
      for(int i=0; i < POSITIONS; i++){
        int pos_id=i;
        if(MyOrderOpenLots(pos_id) == 0){
          
        }
        else if( MyOrderProfitPips(pos_id)>= 5){//ポジションの利益確定
        　MyOrderClose(pos_id);
        }
        else if( MyOrderProfitPips(pos_id)< -50){//ポジションの損切確定
         MyOrderClose(pos_id);
        }
        else if( Time[i] - pos_timestamp[i] >= 60*30){//30分以上経過していたらポジションクローズ
         MyOrderClose(pos_id);
         Print("TimeOver");
        }
      }

      //新規ポジションのオープン判断
      last_timestamp = TimeToStr(Time[1], TIME_DATE|TIME_MINUTES);
      order(dts_short, probs_short, -1);
      order(dts_long, probs_long, 1);
  }
  
}        


//+------------------------------------------------------------------+
//| シグナルの強さに応じてポジションサイズを判断するための関数                                      |
//+------------------------------------------------------------------+
void order(int &dts[], double &probs[], int rec){
      int sellbuy_flg = (rec+1)/2; //sell:1, buy:0　に変換
      int init_sellbuy_pos_id = POSITIONS/2 * sellbuy_flg;　//SELL, BUYごとのポジションID初期値

      double prob_ = read_signal(last_timestamp, dts, probs, rec);

      int max_pos = 0;

      //シグナルの強さに応じて同時にもつ最大ポジション数を調整
      if(prob_ >= 0.85){

        if(prob_>= 0.95){
          max_pos = POSITIONS/2;
        }
        else if(prob_>= 0.9){
          max_pos = 10;
        }     
        else{
          max_pos = 5;
        }

       for(int i=0+init_sellbuy_pos_id; i < max_pos+init_sellbuy_pos_id; i++){
          int pos_id=i;
          if(MyOrderOpenLots(pos_id) != 0 ) break;

          double lots = 0.1+((max_pos/10.0+1)/1.5); //シグナルの強さに応じてロットを調整
          //lots = lots*AccountBalance()/init_balance; //複利を利かす場合はコメントアウト

          if(Time[0] - last_timestamp_sec[sellbuy_flg] > 60*10){ //前回注文時から10分以上経過していたら注文
              MyOrderSendMarket(rec,0,lots,pos_id);
              pos_timestamp[pos_id] = Time[0];
              last_timestamp_sec[sellbuy_flg] = Time[0];
              break;
         　}
      　}
      }
}



//+------------------------------------------------------------------+
//| 指定した時刻のシグナル情報（利益が得られる確率）を返す                                           |
//+------------------------------------------------------------------+
double read_signal(string lts, int &dts[], double &probs[], int rec){
           StringReplace(lts,".","");
           StringReplace(lts,":","");
           StringReplace(lts," ","");
           int lts_i = StrToInteger(lts);
           double prob = 0.0;
           for(int i = PREV_POS[sellbuy_flg]; i<ArraySize(dts); i++){前回処理したindex以降で、指定した時刻のシグナル情報があるかをサーチ
             if(dts[i]==lts_i) {
                prob = probs[i];
                PREV_POS[sellbuy_flg] = i; //今回処理したindexを保持しておく
                return prob;　指定した時刻のシグナル情報があればその値を返す
              }
           }
           return prob;　指定した時刻のシグナル情報がなければ0.0を返す
}




//+------------------------------------------------------------------+
//| シグナル情報を記録したcsvファイルを読み込み、配列としてメモリにキャッシュ                                        |
//+------------------------------------------------------------------+
void cache_signal(string filename, int &dts[], double &probs[]){
string first = "";//一番目のカラム(時刻が格納される)
string second = "";//二番目のカラム(確率が格納される)
//--- reset the error value
   ResetLastError();
//--- open the file for reading (if the file does not exist, the error will occur)
   int file_handle=FileOpen(filename,FILE_READ,",");   
   if(file_handle!=INVALID_HANDLE)
     {
      int i = 0;　 //何行目を読み込むかのインデックス
      //--- print the file contents
      while(!FileIsEnding(file_handle)){
         first = (FileReadString(file_handle));
           second = (FileReadString(file_handle));
           //Print(second);
           double prob = StrToDouble(second);
           StringReplace(first,".","");
           StringReplace(first,":","");
           StringReplace(first," ","");
           dts[i] = StrToInteger(first);
           probs[i] = prob; 
         i = i+1;
      }
      //--- close the file
      FileClose(file_handle);
     }
   else
      PrintFormat("Error, code = %d",GetLastError());
}