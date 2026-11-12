package tw.futuremedialab.frauddetect.kebbi

import android.content.Context
import android.util.Log
import com.nuwarobotics.service.facecontrol.UnityFaceManager
import com.nuwarobotics.service.facecontrol.utils.ServiceConnectListener

/**
 * 凱比臉部表情 (只換臉，不帶表情包的配套身體動作)。
 *
 * 用 UnityFaceManager.playFaceAnimation(動畫名稱)，例如 007_S2_Sad74 (難過流淚)、
 * 007_J3_Happy61 (星星眼)。名稱前綴 007 是這台凱比的臉部角色。
 * 不要用表情包 (JSON) 名稱如 007_P4_RPSTie：表情包會連帶 robotMotion 身體動作。
 * 實機確認：播一次會停在該表情，直到 reset()。
 *
 * 必須先 init() 建立臉部服務連線，否則 isServiceConnected 永遠是 false。
 */
class FaceController(context: Context) {

    companion object {
        private const val TAG = "[KebbiFace]"
    }

    private val face: UnityFaceManager? = try {
        UnityFaceManager.getInstance().init(context.applicationContext, context.packageName,
            object : ServiceConnectListener {
                override fun onConnectChanged(name: android.content.ComponentName?, connected: Boolean) {
                    Log.i(TAG, "face service connected=$connected")
                }
            })
    } catch (t: Throwable) {
        Log.e(TAG, "UnityFaceManager init failed", t)
        null
    }

    /** 顯示臉部並換成指定表情；表情會停住直到 reset() */
    fun show(animationName: String) {
        val f = face ?: return
        try {
            if (!f.isServiceConnected) {
                Log.w(TAG, "face service not connected, skip $animationName")
                return
            }
            f.setAutoIdleAnimState(true)   // 暫停預設待機表情，避免蓋掉
            f.showUnity()
            f.playFaceAnimation(animationName)
            Log.i(TAG, "face $animationName")
        } catch (t: Throwable) {
            Log.e(TAG, "face $animationName failed", t)
        }
    }

    /** 恢復預設臉並收起臉部畫面，回到 App 畫面 */
    fun reset() {
        val f = face ?: return
        try {
            f.stopMotion()
            f.setAutoIdleAnimState(false)
            f.hideUnity()
            Log.i(TAG, "face reset")
        } catch (t: Throwable) {
            Log.e(TAG, "face reset failed", t)
        }
    }
}
