package com.symmetryrush.game

import android.os.Bundle
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Play 게임즈 프로젝트 ID 가 설정돼 있을 때만 초기화한다 (없이 초기화하면 오류가 날 수 있음).
        if (getString(R.string.game_services_project_id).isNotBlank()) {
            PlayGamesSdk.initialize(this)
        }
    }
}
