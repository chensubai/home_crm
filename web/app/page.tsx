"use client";

const APP_STORE_URL = "https://apps.apple.com/app/id0000000000";

function AppMark() {
  return <span className="app-mark" aria-hidden="true"><img src="/AppIcon.png" alt="" /></span>;
}

function Phone({ variant = "spaces" }: { variant?: "spaces" | "reminders" | "family" }) {
  const screenshot = variant === "spaces" ? "/app-spaces.png" : variant === "reminders" ? "/app-reminders.png" : "/app-profile.png";
  return (
    <div className={`phone phone-${variant}`} aria-label="方寸 app 界面预览">
      <img className="app-screenshot" src={screenshot} alt={`${variant === "spaces" ? "空间管理" : variant === "reminders" ? "家庭提醒" : "个人中心"}页面截图`} />
      <div className="legacy-phone-ui" aria-hidden="true">
      <div className="phone-island" />
      <div className="phone-screen">
        <div className="phone-status"><span>9:41</span><span>● ◔ ▰</span></div>
        {variant === "spaces" && <>
          <div className="phone-heading"><div><small>我的家庭</small><strong>今天想找什么？</strong></div><b>＋</b></div>
          <div className="phone-search">⌕　搜索物品</div>
          <div className="phone-grid"><div className="space-card sage"><span>⌂</span><strong>客厅储物柜</strong><small>18 件物品</small></div><div className="space-card sand"><span>▦</span><strong>厨房抽屉</strong><small>12 件物品</small></div><div className="space-card blue"><span>▤</span><strong>玄关收纳</strong><small>8 件物品</small></div><div className="space-card rose"><span>◇</span><strong>卧室衣柜</strong><small>24 件物品</small></div></div>
        </>}
        {variant === "reminders" && <>
          <div className="phone-heading"><div><small>方寸 · 生活</small><strong>家庭提醒</strong></div><b>＋</b></div>
          <div className="reminder-date"><strong>今天</strong><span>8月12日 · 星期三</span></div>
          <div className="reminder-item"><i className="dot green"/><div><strong>更换净水器滤芯</strong><small>10:00 · 每 6 个月</small></div><em>●</em></div>
          <div className="reminder-item"><i className="dot orange"/><div><strong>妈妈的生日</strong><small>明天 · 重要日期</small></div><em>○</em></div>
          <div className="reminder-item muted"><i className="dot gray"/><div><strong>检查药品有效期</strong><small>8月18日 · 物品过期</small></div><em>○</em></div>
        </>}
        {variant === "family" && <>
          <div className="phone-heading"><div><small>我的家庭</small><strong>一起管理，更轻松</strong></div><b>•••</b></div>
          <div className="family-card"><div className="avatar avatar-a">林</div><div><strong>林小满</strong><small>家庭 Owner</small></div><span>在线</span></div>
          <div className="family-card"><div className="avatar avatar-b">爸</div><div><strong>爸爸</strong><small>成员 · 刚刚同步</small></div><span>在线</span></div>
          <div className="family-card"><div className="avatar avatar-c">妈</div><div><strong>妈妈</strong><small>成员 · 2 分钟前</small></div><span>离线</span></div>
          <div className="sync-note">↻　所有内容已同步</div>
        </>}
        <div className="phone-tab"><span>⌂<small>空间</small></span><span>◷<small>提醒</small></span><span>◎<small>个人中心</small></span></div>
      </div>
      </div>
    </div>
  );
}

export default function Home() {
  return <main>
    <nav className="nav"><a className="brand" href="#top"><AppMark /><span>方寸</span></a><div className="nav-links"><a href="#features">功能</a><a href="#about">关于方寸</a><a href="#download">下载</a></div><a className="nav-cta" href={APP_STORE_URL}>下载 App <span>↗</span></a></nav>

    <section className="hero" id="top"><div className="hero-glow" /><div className="hero-copy reveal"><p className="eyebrow">为家而生的物品管理 app</p><h1>把家，装进<br /><em>秩序里。</em></h1><p className="hero-sub">每一件物品都有它的位置。<br />每一个重要的日子，都值得被记住。</p><div className="hero-actions"><a className="button button-light" href={APP_STORE_URL}>下载方寸 <span>↗</span></a><a className="text-link light-link" href="#features">了解功能 <span>↓</span></a></div></div><div className="hero-device reveal delay-1"><div className="orb orb-one" /><div className="orb orb-two" /><Phone /></div><div className="hero-scroll">向下探索 <span>↓</span></div></section>

    <section className="statement" id="about"><p className="eyebrow">为每一个家的日常设计</p><h2>少一点寻找，<br /><span>多一点从容。</span></h2><p className="statement-copy">方寸把物品、空间和提醒放进同一个轻盈的系统里。你和家人随时知道家里有什么、它在哪里，以及接下来要做什么。</p><div className="promise-grid"><div><strong>01</strong><h3>一眼看见</h3><p>把柜子、抽屉和收纳箱整理成清晰的家庭地图。</p></div><div><strong>02</strong><h3>及时想起</h3><p>重要日期、周期任务和物品期限，按时提醒你。</p></div><div><strong>03</strong><h3>一起维护</h3><p>家人共享同一份信息，更新会自然同步。</p></div></div></section>

    <section className="feature feature-sage" id="features"><div className="feature-copy reveal"><p className="eyebrow">空间管理</p><h2>每一件东西，<br /><span>都有它的位置。</span></h2><p>把家里的储物空间变成一张清晰的地图。搜索物品，马上找到它所在的柜子、抽屉或收纳箱。</p><a className="text-link" href={APP_STORE_URL}>了解空间管理 <span>↗</span></a></div><div className="feature-visual visual-spaces reveal delay-1"><Phone variant="spaces" /></div></section>

    <section className="feature feature-dark"><div className="feature-visual visual-reminders reveal"><Phone variant="reminders" /></div><div className="feature-copy light-copy reveal delay-1"><p className="eyebrow">家庭提醒</p><h2>该记住的事，<br /><span>交给方寸。</span></h2><p>重要日期、周期任务、物品过期提醒，一个都不会漏掉。设置一次，按时收到通知。</p><a className="text-link light-link" href={APP_STORE_URL}>了解家庭提醒 <span>↗</span></a></div></section>

    <section className="feature feature-sand"><div className="feature-copy reveal"><p className="eyebrow">家庭协作</p><h2>一个家庭，<br /><span>一份共同的秩序。</span></h2><p>邀请家人加入，共同维护属于你们的家庭空间。每一次更新，都会悄悄同步到每个人手里。</p><a className="text-link" href={APP_STORE_URL}>了解家庭协作 <span>↗</span></a></div><div className="feature-visual visual-family reveal delay-1"><Phone variant="family" /></div></section>

    <section className="tech"><div className="tech-heading"><p className="eyebrow">细节，自然发生</p><h2>让家里的每一次<br /><span>连接都更简单。</span></h2></div><div className="tech-grid"><div className="tech-card"><span className="tech-icon">⌁</span><strong>一碰即达</strong><p>NFC 标签连接空间，让寻找从“记得”变成“碰一下”。</p></div><div className="tech-card"><span className="tech-icon">⌗</span><strong>轻松录入</strong><p>扫描条形码或二维码，物品信息很快就能归位。</p></div><div className="tech-card"><span className="tech-icon">↻</span><strong>始终同步</strong><p>本地缓存与增量同步，让家人的每次更新都不丢失。</p></div></div></section>

    <section className="download" id="download"><div className="download-mark"><AppMark /></div><p className="eyebrow">现在，就从方寸开始</p><h2>让家，回到<br /><em>它本来的样子。</em></h2><p>下载方寸，和家人一起，把生活整理得刚刚好。</p><a className="button button-dark" href={APP_STORE_URL}>前往 App Store <span>↗</span></a></section>

    <footer><a className="brand" href="#top"><AppMark /><span>方寸</span></a><p>把家，装进秩序里。</p><div><span>© 2026 方寸</span><span>京ICP备2026047069号-1</span><a href="#top">回到顶部 ↑</a></div></footer>
  </main>;
}
