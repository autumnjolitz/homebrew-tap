class Xsoldier < Formula
  desc "Space shoot 'em up game with the \"not shooting\" bonus"
  homepage "http://www.interq.or.jp/libra/oohara/xsoldier/index.html"
  url "http://www.interq.or.jp/libra/oohara/xsoldier/xsoldier-1.8.tar.gz"
  sha256 "4d1a60513a2738e5dc09a25b4ab7bdbcd88705a5cc7ef0ad6f27263b914cdae6"
  license "GPL-2.0-or-later"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libICE"
  depends_on "libSM"
  depends_on "libX11"
  depends_on "libXpm"

  patch :p1, :DATA

  def install
    # Remove unrecognized options if they cause configure to fail
    # https://docs.brew.sh/rubydoc/Formula.html#std_configure_args-instance_method
    system "autoreconf", "-i"
    system "./configure", "--disable-silent-rules", *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    system "#{bin}/xsoldier", "--help"
  end
end
__END__
diff --git a/enemyshot.c b/enemyshot.c
index 0a11448..afa5c51 100644
--- a/enemyshot.c
+++ b/enemyshot.c
@@ -14,6 +14,7 @@
 #include <X11/xpm.h>
 */
 
+#include <stdlib.h>
 #include "image.h"
 #include "xsoldier.h"
 #include "manage.h"
diff --git a/game.c b/game.c
index 3481bcf..7fa3dbc 100644
--- a/game.c
+++ b/game.c
@@ -275,24 +275,24 @@ int mainLoop(void)
               /* shoot down bonus message */
               if (manage->BossTime >= 1)
               {
-		sprintf(Percent,"shoot down %02d%%",player->Percent);
+		snprintf(Percent, sizeof(Percent), "shoot down %02d%%",player->Percent);
                 draw_string(210, 370, Percent, strlen(Percent));
 
 
-		sprintf(Bonus,"Bonus %d pts", shoot_down_bonus(player->Percent, manage->Loop, manage->Stage));
+		snprintf(Bonus, sizeof(Bonus), "Bonus %d pts", shoot_down_bonus(player->Percent, manage->Loop, manage->Stage));
                 draw_string(260 + manage->Appear*3 , 400,
                             Bonus, strlen(Bonus));
 
 		if (player->Percent >= 100)
 		{
-		    sprintf(Perfect,"Perfect!!");
+		    snprintf(Perfect, sizeof(Perfect), "Perfect!!");
                     draw_string(170 - manage->Appear*3 , 420,
                                 Perfect, strlen(Perfect));
 		}
               }
               else
               {
-                snprintf(Percent, 32, "the boss escaped");
+                snprintf(Percent, sizeof(Percent), "the boss escaped");
                 draw_string(200 ,370 ,Percent, strlen(Percent));
               }
               
@@ -335,19 +335,19 @@ static void DrawInfo(void)
     
     int i;
 
-    sprintf(Score,"Score % 8d",player->Rec[0].score);
-    sprintf(Stage,"Stage %2d",manage->Stage);
-    sprintf(Ships,"Ships %3d",player->Ships);
+    snprintf(Score, sizeof(Score), "Score % 8d",player->Rec[0].score);
+    snprintf(Stage, sizeof(Stage), "Stage %2d",manage->Stage);
+    snprintf(Ships, sizeof(Ships), "Ships %3d",player->Ships);
 #ifdef DEBUG
-    sprintf(ObjectE,"Enemy Object %3d",manage->EnemyNum);
-    sprintf(ObjectP,"Player Object %3d",manage->PlayerNum);
-    sprintf(Loop,"Loop %2d",manage->Loop);
-    sprintf(Level,"Level %3d",manage->Level);
-    sprintf(Weapon,"Weapon %d",manage->player[0]->Data.Cnt[5]);
-    sprintf(Pow,"Pow %2d",manage->player[0]->Data.Cnt[6]);
-    sprintf(Speed,"Speed %2d",manage->player[0]->Data.Speed);
-    sprintf(Enemy,"Enemy %3d",manage->StageEnemy);
-    sprintf(EnemyKill,"EnemyKill %3d",manage->StageShotDown);
+    snprintf(ObjectE, sizeof(ObjectE), "Enemy Object %3d",manage->EnemyNum);
+    snprintf(ObjectP, sizeof(ObjectP), "Player Object %3d",manage->PlayerNum);
+    snprintf(Loop, sizeof(Loop), "Loop %2d",manage->Loop);
+    snprintf(Level, sizeof(Level), "Level %3d",manage->Level);
+    snprintf(Weapon, sizeof(Weapon), "Weapon %d",manage->player[0]->Data.Cnt[5]);
+    snprintf(Pow, sizeof(Pow), "Pow %2d",manage->player[0]->Data.Cnt[6]);
+    snprintf(Speed, sizeof(Speed), "Speed %2d",manage->player[0]->Data.Speed);
+    snprintf(Enemy, sizeof(Enemy), "Enemy %3d",manage->StageEnemy);
+    snprintf(EnemyKill, sizeof(EnemyKill), "EnemyKill %3d",manage->StageShotDown);
 #endif
 
     draw_string(10, 20, Score, strlen(Score));
diff --git a/main.c b/main.c
index b4ca381..cacdb35 100644
--- a/main.c
+++ b/main.c
@@ -33,7 +33,6 @@
 /* DeleteAllStar */
 #include "star.h"
 #include "score.h"
-#include "wait.h"
 #include "graphic.h"
 #include "input.h"
 
@@ -175,7 +174,7 @@ static void arginit(int argc, char *argv[])
                         i + 1);
                 display[sizeof(display) - 1] = '\0';
                 fprintf(stderr, "truncated to %d chars\n",
-                        sizeof(display) - 1);
+                        (int)sizeof(display) - 1);
               }
               i++;
             }
diff --git a/manage.c b/manage.c
index 4e4008f..8007f52 100644
--- a/manage.c
+++ b/manage.c
@@ -17,7 +17,6 @@
 
 #include <stdio.h>
 #include <stdlib.h>
-#include <malloc.h>
 /*
 #include <X11/Xlib.h>
 #include <X11/Xutil.h>
@@ -394,7 +393,7 @@ PlayerData *NewPlayerData(void)
 
     New = (PlayerData *)malloc(sizeof(PlayerData));
 
-    sprintf(New->Rec[0].name,name);
+    snprintf(New->Rec[0].name, sizeof(New->Rec[0].name), name);
     New->Rec[0].score = 0;
     New->Rec[0].stage = 0;
     New->Rec[0].loop = 0;
diff --git a/opening.c b/opening.c
index f881983..e7086c7 100644
--- a/opening.c
+++ b/opening.c
@@ -95,10 +95,10 @@ int Opening(void)
 	    {
 		draw_string(120, 330+i*25, player->Rec[i].name,
                             strlen(player->Rec[i].name));
-		sprintf(buff,"%2d-%2d",player->Rec[i].loop,
+		snprintf(buff, sizeof(buff), "%2d-%2d",player->Rec[i].loop,
                         player->Rec[i].stage);
 		draw_string(270, 330+i*25, buff, strlen(buff));
-		sprintf(buff,"%8d",player->Rec[i].score);
+		snprintf(buff, sizeof(buff), "%8d",player->Rec[i].score);
 		draw_string(350, 330+i*25, buff, strlen(buff));
 	    }
 	}
