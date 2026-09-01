package com.pangchuang.app

import android.app.Activity
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams

class BillingManager(
    private val activity: Activity,
    private val prefs: Prefs,
    private val listener: Listener,
) : PurchasesUpdatedListener, BillingClientStateListener {

    interface Listener {
        fun onBillingReady(priceLabel: String?)
        fun onPurchaseStateChanged(unlocked: Boolean)
        fun onPurchaseMessage(message: String)
    }

    private val billingClient: BillingClient = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases()
        .build()

    private var productDetails: ProductDetails? = null

    fun start() {
        if (!billingClient.isReady) {
            billingClient.startConnection(this)
        } else {
            refreshCatalogAndPurchases()
        }
    }

    fun stop() {
        if (billingClient.isReady) {
            billingClient.endConnection()
        }
    }

    fun launchPurchase() {
        if (!billingClient.isReady) {
            listener.onPurchaseMessage(activity.getString(R.string.purchase_billing_unavailable))
            start()
            return
        }
        val details = productDetails
        if (details == null) {
            listener.onPurchaseMessage(activity.getString(R.string.purchase_billing_unavailable))
            queryProductDetails()
            return
        }
        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .build()
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParams))
            .build()
        val result = billingClient.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            listener.onPurchaseMessage(activity.getString(R.string.purchase_failed))
        }
    }

    fun restorePurchases() {
        if (!billingClient.isReady) {
            listener.onPurchaseMessage(activity.getString(R.string.purchase_billing_unavailable))
            start()
            return
        }
        queryPurchases(showRestoreMessage = true)
    }

    override fun onBillingSetupFinished(billingResult: BillingResult) {
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
            refreshCatalogAndPurchases()
        } else {
            listener.onBillingReady(null)
            listener.onPurchaseStateChanged(prefs.isPremiumUnlocked)
        }
    }

    override fun onBillingServiceDisconnected() {
        // Play services may reconnect on the next user action.
    }

    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: MutableList<Purchase>?) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases?.forEach { handlePurchase(it) }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                listener.onPurchaseMessage(activity.getString(R.string.purchase_canceled))
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                queryPurchases(showRestoreMessage = false)
                listener.onPurchaseMessage(activity.getString(R.string.purchase_success))
            }
            else -> {
                listener.onPurchaseMessage(activity.getString(R.string.purchase_failed))
            }
        }
    }

    private fun refreshCatalogAndPurchases() {
        queryProductDetails()
        queryPurchases(showRestoreMessage = false)
    }

    private fun queryProductDetails() {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(PRODUCT_FULL_UNLOCK)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()
                )
            )
            .build()
        billingClient.queryProductDetailsAsync(params) { billingResult, detailsList ->
            if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                listener.onBillingReady(null)
                return@queryProductDetailsAsync
            }
            productDetails = detailsList.firstOrNull()
            val price = productDetails?.oneTimePurchaseOfferDetails?.formattedPrice
            listener.onBillingReady(price)
        }
    }

    private fun queryPurchases(showRestoreMessage: Boolean) {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()
        billingClient.queryPurchasesAsync(params) { billingResult, purchases ->
            if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                listener.onPurchaseStateChanged(prefs.isPremiumUnlocked)
                if (showRestoreMessage) {
                    listener.onPurchaseMessage(activity.getString(R.string.purchase_restore_none))
                }
                return@queryPurchasesAsync
            }
            var unlocked = false
            purchases.forEach { purchase ->
                if (isOurProduct(purchase) && purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                    unlocked = true
                    acknowledgeIfNeeded(purchase)
                }
            }
            prefs.isPremiumUnlocked = unlocked
            listener.onPurchaseStateChanged(unlocked)
            if (showRestoreMessage) {
                listener.onPurchaseMessage(
                    if (unlocked) activity.getString(R.string.purchase_success)
                    else activity.getString(R.string.purchase_restore_none)
                )
            }
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (!isOurProduct(purchase)) return
        when (purchase.purchaseState) {
            Purchase.PurchaseState.PURCHASED -> {
                acknowledgeIfNeeded(purchase)
                prefs.isPremiumUnlocked = true
                listener.onPurchaseStateChanged(true)
                listener.onPurchaseMessage(activity.getString(R.string.purchase_success))
            }
            Purchase.PurchaseState.PENDING -> {
                listener.onPurchaseMessage(activity.getString(R.string.purchase_pending))
            }
            else -> Unit
        }
    }

    private fun acknowledgeIfNeeded(purchase: Purchase) {
        if (purchase.isAcknowledged) return
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        billingClient.acknowledgePurchase(params) { /* entitlement already granted */ }
    }

    private fun isOurProduct(purchase: Purchase): Boolean {
        return purchase.products.contains(PRODUCT_FULL_UNLOCK)
    }

    companion object {
        const val PRODUCT_FULL_UNLOCK = "full_unlock"
    }
}
