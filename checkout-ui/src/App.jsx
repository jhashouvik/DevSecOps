import React, { useState, useEffect } from 'react';

function App() {
  const [paymentMethod, setPaymentMethod] = useState('card');
  const [checkoutState, setCheckoutState] = useState('idle'); // idle, processing, success
  const [countdown, setCountdown] = useState(600); // 10 minutes checkout window
  const [formData, setFormData] = useState({ name: '', cardNumber: '', expiry: '', cvc: '' });

  // Simulate a countdown timer for security compliance (PCI-DSS session limits)
  useEffect(() => {
    if (countdown <= 0 || checkoutState === 'success') return;
    const timer = setInterval(() => setCountdown(prev => prev - 1), 1000);
    return () => clearInterval(timer);
  }, [countdown, checkoutState]);

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handlePaymentSubmit = (e) => {
    e.preventDefault();
    setCheckoutState('processing');

    // Simulate asymmetrical API request traveling through CloudFront -> ALB -> App VPC
    setTimeout(() => {
      setCheckoutState('success');
    }, 2500);
  };

  return (
    <div style={{ fontFamily: '"SF Pro Display", -apple-system, BlinkMacSystemFont, sans-serif', backgroundColor: '#f8fafc', color: '#0f172a', minHeight: '100vh', padding: '40px 20px' }}>
      
      {/* Institutional Branding Header */}
      <header style={{ maxWidth: '1000px', margin: '0 auto 30px auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid #e2e8f0', paddingBottom: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <div style={{ width: '12px', height: '24px', backgroundColor: '#6366f1', borderRadius: '3px', transform: 'skewX(-15deg)' }}></div>
          <span style={{ fontWeight: '700', fontSize: '18px', letterSpacing: '-0.5px' }}>WEZVATECH <span style={{ color: '#6366f1', fontWeight: '400' }}>Demo Gateway</span></span>
        </div>
        <div style={{ backgroundColor: '#fee2e2', color: '#ef4444', padding: '6px 12px', borderRadius: '6px', fontSize: '13px', fontWeight: '600', fontFamily: 'monospace' }}>
          Session Security Expires: {formatTime(countdown)}
        </div>
      </header>

      {/* Primary Layout Engine */}
      <main style={{ maxWidth: '1000px', margin: '0 auto', display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(350px, 1fr))', gap: '40px' }}>
        
        {/* LEFT COLUMN: THE INTERACTIVE PAYMENT ENGINE */}
        <div style={{ backgroundColor: '#ffffff', padding: '40px', borderRadius: '16px', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.05), 0 2px 4px -2px rgb(0 0 0 / 0.05)', border: '1px solid #f1f5f9' }}>
          {checkoutState === 'idle' && (
            <div>
              <h2 style={{ margin: '0 0 6px 0', fontSize: '22px', fontWeight: '700' }}>Secure Checkout</h2>
              <p style={{ margin: '0 0 24px 0', color: '#64748b', fontSize: '14px' }}>Select preferred multi-tenant settlement framework.</p>

              {/* Selector Tabs for Methods */}
              <div style={{ display: 'flex', gap: '12px', marginBottom: '24px' }}>
                <button onClick={() => setPaymentMethod('card')} style={{ flex: 1, backgroundColor: paymentMethod === 'card' ? '#eef2ff' : '#fff', border: paymentMethod === 'card' ? '2px solid #6366f1' : '1px solid #cbd5e1', padding: '12px', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', color: paymentMethod === 'card' ? '#4f46e5' : '#475569' }}>
                  💳 Credit/Debit Card
                </button>
                <button onClick={() => setPaymentMethod('upi')} style={{ flex: 1, backgroundColor: paymentMethod === 'upi' ? '#eef2ff' : '#fff', border: paymentMethod === 'upi' ? '2px solid #6366f1' : '1px solid #cbd5e1', padding: '12px', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', color: paymentMethod === 'upi' ? '#4f46e5' : '#475569' }}>
                  ⚡ UPI Instant Link
                </button>
              </div>

              <form onSubmit={handlePaymentSubmit}>
                {paymentMethod === 'card' ? (
                  <div>
                    <div style={{ marginBottom: '16px' }}>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#475569', marginBottom: '6px', textTransform: 'uppercase' }}>Cardholder Name</label>
                      <input type="text" name="name" required value={formData.name} onChange={handleInputChange} placeholder="Adam M" style={{ width: '100%', boxSizing: 'border-box', border: '1px solid #cbd5e1', padding: '12px', borderRadius: '6px', fontSize: '15px' }} />
                    </div>
                    <div style={{ marginBottom: '16px' }}>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#475569', marginBottom: '6px', textTransform: 'uppercase' }}>Card Number</label>
                      <input type="text" name="cardNumber" required maxLength="19" value={formData.cardNumber} onChange={handleInputChange} placeholder="4111 2222 3333 4444" style={{ width: '100%', boxSizing: 'border-box', border: '1px solid #cbd5e1', padding: '12px', borderRadius: '6px', fontSize: '15px', fontFamily: 'monospace' }} />
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '24px' }}>
                      <div>
                        <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#475569', marginBottom: '6px', textTransform: 'uppercase' }}>Expiry Date</label>
                        <input type="text" name="expiry" required maxLength="5" value={formData.expiry} onChange={handleInputChange} placeholder="MM/YY" style={{ width: '100%', boxSizing: 'border-box', border: '1px solid #cbd5e1', padding: '12px', borderRadius: '6px', fontSize: '15px', textAlign: 'center' }} />
                      </div>
                      <div>
                        <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#475569', marginBottom: '6px', textTransform: 'uppercase' }}>Security Code (CVC)</label>
                        <input type="password" name="cvc" required maxLength="3" value={formData.cvc} onChange={handleInputChange} placeholder="•••" style={{ width: '100%', boxSizing: 'border-box', border: '1px solid #cbd5e1', padding: '12px', borderRadius: '6px', fontSize: '15px', textAlign: 'center' }} />
                      </div>
                    </div>
                  </div>
                ) : (
                  <div style={{ marginBottom: '24px' }}>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#475569', marginBottom: '6px', textTransform: 'uppercase' }}>Virtual Payment Address (VPA)</label>
                    <input type="text" required placeholder="merchantname@bank" style={{ width: '100%', boxSizing: 'border-box', border: '1px solid #cbd5e1', padding: '12px', borderRadius: '6px', fontSize: '15px' }} />
                  </div>
                )}

                <button type="submit" style={{ width: '100%', backgroundColor: '#4f46e5', color: '#fff', border: 'none', padding: '14px', borderRadius: '8px', fontSize: '16px', fontWeight: '600', cursor: 'pointer', boxShadow: '0 4px 6px -1px rgb(79 70 229 / 0.2)' }}>
                  Authorize & Pay $450.00
                </button>
              </form>
            </div>
          )}

          {/* CHECKOUT STATE: PROCESSING TRANSACTION */}
          {checkoutState === 'processing' && (
            <div style={{ textAlign: 'center', padding: '40px 0' }}>
              <div style={{ width: '50px', height: '50px', border: '4px solid #e2e8f0', borderTop: '4px solid #4f46e5', borderRadius: '50%', animation: 'spin 1s linear infinite', margin: '0 auto 24px auto' }}></div>
              <h3 style={{ margin: '0 0 8px 0', fontSize: '18px' }}>Encrypting Transaction Artifacts</h3>
              <p style={{ margin: '0', color: '#64748b', fontSize: '14px' }}>Routing payload safely through isolated subnets to core ledgers...</p>
              
              {/* Native spinning style tag injection */}
              <style>{`@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }`}</style>
            </div>
          )}

          {/* CHECKOUT STATE: SUCCESS ACQUIRED */}
          {checkoutState === 'success' && (
            <div style={{ textAlign: 'center', padding: '40px 0' }}>
              <div style={{ width: '60px', height: '60px', backgroundColor: '#dcfce7', borderRadius: '50%', display: 'flex', alignItems: 'center', justifycontent: 'center', color: '#15803d', fontSize: '30px', fontWeight: 'bold', margin: '0 auto 24px auto', lineHeight: '60px' }}>✓</div>
              <h3 style={{ margin: '0 0 8px 0', fontSize: '20px', color: '#16a34a' }}>Settlement Complete</h3>
              <p style={{ margin: '0 0 12px 0', color: '#64748b', fontSize: '14px' }}>ISO 20022 message signed and verified.</p>
              <p style={{ margin: '0', color: '#475569', fontSize: '12px', fontFamily: 'monospace', backgroundColor: '#f1f5f9', padding: '8px', borderRadius: '4px' }}>TXN-HASH: 8f9a2c4e6b8d0e1f</p>
              <button onClick={() => setCheckoutState('idle')} style={{ marginTop: '24px', backgroundColor: '#transparent', border: '1px solid #cbd5e1', padding: '8px 16px', borderRadius: '6px', cursor: 'pointer' }}>Reset Demo Instance</button>
            </div>
          )}
        </div>

        {/* RIGHT COLUMN: ORDER SUMMARY & INFRASTRUCTURE TELEMETRY */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '30px' }}>
          
          {/* Order Snapshot Card */}
          <div style={{ backgroundColor: '#0f172a', color: '#f8fafc', padding: '30px', borderRadius: '16px' }}>
            <h3 style={{ margin: '0 0 20px 0', fontSize: '16px', color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Merchant Invoice</h3>
            <div style={{ borderBottom: '1px solid #334155', paddingBottom: '16px', marginBottom: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                <span>Global Liquidity Vault Alpha</span>
                <span style={{ fontWeight: '600' }}>$400.00</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: '#94a3b8', fontSize: '14px' }}>
                <span>Interbank Network Clearing Fee</span>
                <span>$50.00</span>
              </div>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '18px', fontWeight: '700' }}>
              <span>Total Ledger Due:</span>
              <span style={{ color: '#38bdf8', fontFamily: 'monospace' }}>$450.00</span>
            </div>
          </div>

          {/* DevOps Insights Classroom Mirror */}
          <div style={{ backgroundColor: '#f1f5f9', border: '1px solid #e2e8f0', padding: '24px', borderRadius: '12px' }}>
            <h4 style={{ margin: '0 0 10px 0', fontSize: '14px', color: '#475569', textTransform: 'uppercase' }}>💡 Platform SRE Infrastructure Note</h4>
            <p style={{ margin: 0, fontSize: '13px', color: '#64748b', lineHeight: '1.6' }}>
              This sandbox webpage simulates a production UI layer. The compiled JavaScript bundle and CSS styles are stored as static artifacts in your <strong>private S3 bucket</strong>.
            </p>
            <p style={{ margin: '10px 0 0 0', fontSize: '13px', color: '#64748b', lineHeight: '1.6' }}>
              When a user browses here, <strong>Amazon CloudFront</strong> decrypts and serves these files instantly from global edge nodes without opening up your storage container directly to public attacks.
            </p>
          </div>

        </div>
      </main>
    </div>
  );
}

export default App;
